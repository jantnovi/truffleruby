/*
 * Copyright (c) 2015, 2020 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby;

import java.util.Arrays;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.locks.ReentrantLock;

import com.oracle.truffle.api.CompilerAsserts;
import com.oracle.truffle.api.CompilerDirectives;
import com.oracle.truffle.api.instrumentation.AllocationReporter;
import com.oracle.truffle.api.object.Shape;
import org.graalvm.options.OptionDescriptors;
import org.jcodings.Encoding;
import org.truffleruby.builtins.PrimitiveManager;
import org.truffleruby.core.RubyHandle;
import org.truffleruby.core.array.RubyArray;
import org.truffleruby.core.basicobject.RubyBasicObject;
import org.truffleruby.core.binding.RubyBinding;
import org.truffleruby.core.encoding.RubyEncoding;
import org.truffleruby.core.encoding.RubyEncodingConverter;
import org.truffleruby.core.exception.RubyException;
import org.truffleruby.core.exception.RubyFrozenError;
import org.truffleruby.core.exception.RubyNameError;
import org.truffleruby.core.exception.RubyNoMethodError;
import org.truffleruby.core.exception.RubySyntaxError;
import org.truffleruby.core.exception.RubySystemCallError;
import org.truffleruby.core.exception.RubySystemExit;
import org.truffleruby.core.fiber.RubyFiber;
import org.truffleruby.core.hash.RubyHash;
import org.graalvm.options.OptionValues;
import org.truffleruby.core.inlined.CoreMethodAssumptions;
import org.truffleruby.core.kernel.TraceManager;
import org.truffleruby.core.klass.RubyClass;
import org.truffleruby.core.method.RubyMethod;
import org.truffleruby.core.method.RubyUnboundMethod;
import org.truffleruby.core.module.RubyModule;
import org.truffleruby.core.mutex.RubyConditionVariable;
import org.truffleruby.core.mutex.RubyMutex;
import org.truffleruby.core.objectspace.ObjectSpaceManager;
import org.truffleruby.core.objectspace.RubyWeakMap;
import org.truffleruby.core.proc.RubyProc;
import org.truffleruby.core.queue.RubyQueue;
import org.truffleruby.core.queue.RubySizedQueue;
import org.truffleruby.core.range.RubyIntRange;
import org.truffleruby.core.range.RubyLongRange;
import org.truffleruby.core.range.RubyObjectRange;
import org.truffleruby.core.regexp.RubyMatchData;
import org.truffleruby.core.rope.CodeRange;
import org.truffleruby.core.rope.Rope;
import org.truffleruby.core.rope.RopeCache;
import org.truffleruby.core.string.CoreStrings;
import org.truffleruby.core.string.FrozenStringLiterals;
import org.truffleruby.core.string.RubyString;
import org.truffleruby.core.string.StringUtils;
import org.truffleruby.core.support.RubyByteArray;
import org.truffleruby.core.support.RubyCustomRandomizer;
import org.truffleruby.core.support.RubyIO;
import org.truffleruby.core.support.RubyPRNGRandomizer;
import org.truffleruby.core.support.RubySecureRandomizer;
import org.truffleruby.core.symbol.CoreSymbols;
import org.truffleruby.core.symbol.RubySymbol;
import org.truffleruby.core.symbol.SymbolTable;
import org.truffleruby.core.thread.RubyBacktraceLocation;
import org.truffleruby.core.thread.RubyThread;
import org.truffleruby.core.time.RubyTime;
import org.truffleruby.core.tracepoint.RubyTracePoint;
import org.truffleruby.extra.RubyAtomicReference;
import org.truffleruby.extra.ffi.RubyPointer;
import org.truffleruby.core.string.ImmutableRubyString;
import org.truffleruby.language.NotProvided;
import org.truffleruby.language.RubyDynamicObject;
import org.truffleruby.language.RubyEvalInteractiveRootNode;
import org.truffleruby.language.RubyInlineParsingRequestNode;
import org.truffleruby.language.RubyParsingRequestNode;
import org.truffleruby.language.objects.RubyObjectType;
import org.truffleruby.language.objects.classvariables.ClassVariableStorage;
import org.truffleruby.options.LanguageOptions;
import org.truffleruby.platform.Platform;
import org.truffleruby.shared.Metrics;
import org.truffleruby.shared.TruffleRuby;
import org.truffleruby.shared.options.OptionsCatalog;
import org.truffleruby.stdlib.CoverageManager;

import com.oracle.truffle.api.Assumption;
import com.oracle.truffle.api.CompilerDirectives.CompilationFinal;
import com.oracle.truffle.api.CompilerDirectives.TruffleBoundary;
import com.oracle.truffle.api.RootCallTarget;
import com.oracle.truffle.api.Truffle;
import com.oracle.truffle.api.TruffleLanguage;
import com.oracle.truffle.api.TruffleLanguage.ContextPolicy;
import com.oracle.truffle.api.TruffleLogger;
import com.oracle.truffle.api.instrumentation.ProvidedTags;
import com.oracle.truffle.api.instrumentation.StandardTags;
import com.oracle.truffle.api.nodes.ExecutableNode;
import com.oracle.truffle.api.utilities.CyclicAssumption;
import org.truffleruby.stdlib.digest.RubyDigest;

@TruffleLanguage.Registration(
        name = "Ruby",
        contextPolicy = ContextPolicy.EXCLUSIVE,
        id = TruffleRuby.LANGUAGE_ID,
        implementationName = TruffleRuby.FORMAL_NAME,
        version = TruffleRuby.LANGUAGE_VERSION,
        characterMimeTypes = TruffleRuby.MIME_TYPE,
        defaultMimeType = TruffleRuby.MIME_TYPE,
        dependentLanguages = { "nfi", "llvm", "regex" },
        fileTypeDetectors = RubyFileTypeDetector.class)
@ProvidedTags({
        CoverageManager.LineTag.class,
        TraceManager.CallTag.class,
        TraceManager.ClassTag.class,
        TraceManager.LineTag.class,
        TraceManager.NeverTag.class,
        StandardTags.RootTag.class,
        StandardTags.StatementTag.class,
        StandardTags.ReadVariableTag.class,
        StandardTags.WriteVariableTag.class,
})
public final class RubyLanguage extends TruffleLanguage<RubyContext> {

    public static final String PLATFORM = String.format(
            "%s-%s%s",
            Platform.getArchName(),
            Platform.getOSName(),
            Platform.getKernelMajorVersion());

    public static final String LLVM_BITCODE_MIME_TYPE = "application/x-llvm-ir-bitcode";

    public static final String CEXT_EXTENSION = Platform.CEXT_SUFFIX;

    public static final String RESOURCE_SCHEME = "resource:";

    public static final TruffleLogger LOGGER = TruffleLogger.getLogger(TruffleRuby.LANGUAGE_ID);

    private final CyclicAssumption tracingCyclicAssumption = new CyclicAssumption("object-space-tracing");
    @CompilationFinal private volatile Assumption tracingAssumption = tracingCyclicAssumption.getAssumption();
    public final Assumption singleContextAssumption = Truffle
            .getRuntime()
            .createAssumption("single RubyContext per RubyLanguage instance");
    public final CyclicAssumption traceFuncUnusedAssumption = new CyclicAssumption("set_trace_func is not used");

    private final ReentrantLock safepointLock = new ReentrantLock();
    @CompilationFinal private Assumption safepointAssumption = Truffle
            .getRuntime()
            .createAssumption("SafepointManager");

    public final CoreMethodAssumptions coreMethodAssumptions;
    public final CoreStrings coreStrings;
    public final CoreSymbols coreSymbols;
    public final PrimitiveManager primitiveManager;
    public final RopeCache ropeCache;
    public final SymbolTable symbolTable;
    public final FrozenStringLiterals frozenStringLiterals;
    @CompilationFinal public LanguageOptions options;

    @CompilationFinal private AllocationReporter allocationReporter;

    private final AtomicLong nextObjectID = new AtomicLong(ObjectSpaceManager.INITIAL_LANGUAGE_OBJECT_ID);

    private static final RubyObjectType objectType = new RubyObjectType();

    public final Shape basicObjectShape = createShape(RubyBasicObject.class);
    public final Shape moduleShape = createShape(RubyModule.class);
    public final Shape classShape = createShape(RubyClass.class);

    public final Shape arrayShape = createShape(RubyArray.class);
    public final Shape atomicReferenceShape = createShape(RubyAtomicReference.class);
    public final Shape bindingShape = createShape(RubyBinding.class);
    public final Shape byteArrayShape = createShape(RubyByteArray.class);
    public final Shape conditionVariableShape = createShape(RubyConditionVariable.class);
    public final Shape customRandomizerShape = createShape(RubyCustomRandomizer.class);
    public final Shape digestShape = createShape(RubyDigest.class);
    public final Shape encodingConverterShape = createShape(RubyEncodingConverter.class);
    public final Shape encodingShape = createShape(RubyEncoding.class);
    public final Shape exceptionShape = createShape(RubyException.class);
    public final Shape fiberShape = createShape(RubyFiber.class);
    public final Shape frozenErrorShape = createShape(RubyFrozenError.class);
    public final Shape handleShape = createShape(RubyHandle.class);
    public final Shape hashShape = createShape(RubyHash.class);
    public final Shape intRangeShape = createShape(RubyIntRange.class);
    public final Shape ioShape = createShape(RubyIO.class);
    public final Shape longRangeShape = createShape(RubyLongRange.class);
    public final Shape matchDataShape = createShape(RubyMatchData.class);
    public final Shape methodShape = createShape(RubyMethod.class);
    public final Shape mutexShape = createShape(RubyMutex.class);
    public final Shape nameErrorShape = createShape(RubyNameError.class);
    public final Shape noMethodErrorShape = createShape(RubyNoMethodError.class);
    public final Shape objectRangeShape = createShape(RubyObjectRange.class);
    public final Shape procShape = createShape(RubyProc.class);
    public final Shape queueShape = createShape(RubyQueue.class);
    public final Shape prngRandomizerShape = createShape(RubyPRNGRandomizer.class);
    public final Shape secureRandomizerShape = createShape(RubySecureRandomizer.class);
    public final Shape sizedQueueShape = createShape(RubySizedQueue.class);
    public final Shape stringShape = createShape(RubyString.class);
    public final Shape syntaxErrorShape = createShape(RubySyntaxError.class);
    public final Shape systemCallErrorShape = createShape(RubySystemCallError.class);
    public final Shape systemExitShape = createShape(RubySystemExit.class);
    public final Shape threadBacktraceLocationShape = createShape(RubyBacktraceLocation.class);
    public final Shape threadShape = createShape(RubyThread.class);
    public final Shape timeShape = createShape(RubyTime.class);
    public final Shape tracePointShape = createShape(RubyTracePoint.class);
    public final Shape truffleFFIPointerShape = createShape(RubyPointer.class);
    public final Shape unboundMethodShape = createShape(RubyUnboundMethod.class);
    public final Shape weakMapShape = createShape(RubyWeakMap.class);

    public final Shape classVariableShape = Shape
            .newBuilder()
            .allowImplicitCastIntToLong(true)
            .layout(ClassVariableStorage.class)
            .build();

    public RubyLanguage() {
        coreMethodAssumptions = new CoreMethodAssumptions(this);
        coreStrings = new CoreStrings(this);
        coreSymbols = new CoreSymbols();
        primitiveManager = new PrimitiveManager();
        ropeCache = new RopeCache(coreSymbols);
        symbolTable = new SymbolTable(ropeCache, coreSymbols);
        frozenStringLiterals = new FrozenStringLiterals(ropeCache);
    }

    @TruffleBoundary
    public RubySymbol getSymbol(String string) {
        return symbolTable.getSymbol(string);
    }


    @TruffleBoundary
    public RubySymbol getSymbol(Rope rope) {
        return symbolTable.getSymbol(rope);
    }

    public Assumption getTracingAssumption() {
        return tracingAssumption;
    }

    public void invalidateTracingAssumption() {
        tracingCyclicAssumption.invalidate();
        tracingAssumption = tracingCyclicAssumption.getAssumption();
    }

    public Assumption getSafepointAssumption() {
        return safepointAssumption;
    }

    public void invalidateSafepointAssumption(String reason) {
        safepointLock.lock();
        safepointAssumption.invalidate(reason);
    }

    public void resetSafepointAssumption() {
        safepointAssumption = Truffle.getRuntime().createAssumption("SafepointManager");
        safepointLock.unlock();
    }

    @Override
    protected void initializeMultipleContexts() {
        // TODO Make Symbol.all_symbols per context, by having a SymbolTable per context and creating new symbols with
        //  the per-language SymbolTable.
        singleContextAssumption.invalidate();
    }

    @Override
    public RubyContext createContext(Env env) {
        // We need to initialize the Metrics class of the language classloader
        Metrics.initializeOption();

        synchronized (this) {
            if (allocationReporter == null) {
                allocationReporter = env.lookup(AllocationReporter.class);
            }
            if (this.options == null) {
                this.options = new LanguageOptions(env, env.getOptions());
                primitiveManager.loadCoreMethodNodes(this.options);
            }
        }

        LOGGER.fine("createContext()");
        Metrics.printTime("before-create-context");
        // TODO CS 3-Dec-16 need to parse RUBYOPT here if it hasn't been already?
        final RubyContext context = new RubyContext(this, env);
        Metrics.printTime("after-create-context");
        return context;
    }

    @Override
    protected void initializeContext(RubyContext context) throws Exception {
        LOGGER.fine("initializeContext()");

        try {
            Metrics.printTime("before-initialize-context");
            context.initialize();
            Metrics.printTime("after-initialize-context");
        } catch (Throwable e) {
            if (context.getOptions().EXCEPTIONS_PRINT_JAVA || context.getOptions().EXCEPTIONS_PRINT_UNCAUGHT_JAVA) {
                e.printStackTrace();
            }
            throw e;
        }
    }

    @Override
    protected boolean patchContext(RubyContext context, Env newEnv) {
        // We need to initialize the Metrics class of the language classloader
        Metrics.initializeOption();

        LOGGER.fine("patchContext()");
        Metrics.printTime("before-patch-context");
        final LanguageOptions oldOptions = Objects.requireNonNull(this.options);
        final LanguageOptions newOptions = new LanguageOptions(newEnv, newEnv.getOptions());
        if (!LanguageOptions.areOptionsCompatibleOrLog(LOGGER, oldOptions, newOptions)) {
            return false;
        }

        boolean patched = context.patchContext(newEnv);
        Metrics.printTime("after-patch-context");
        return patched;
    }

    @Override
    protected void finalizeContext(RubyContext context) {
        LOGGER.fine("finalizeContext()");
        context.finalizeContext();
    }

    @Override
    protected void disposeContext(RubyContext context) {
        LOGGER.fine("disposeContext()");
        context.disposeContext();
    }

    public static RubyContext getCurrentContext() {
        CompilerAsserts.neverPartOfCompilation("Use getContext() or @CachedContext instead in PE code");
        return getCurrentContext(RubyLanguage.class);
    }

    public static RubyLanguage getCurrentLanguage() {
        CompilerAsserts.neverPartOfCompilation("Use getLanguage() or @CachedLanguage instead in PE code");
        return getCurrentLanguage(RubyLanguage.class);
    }

    @Override
    protected RootCallTarget parse(ParsingRequest request) {
        if (request.getSource().isInteractive()) {
            return Truffle.getRuntime().createCallTarget(new RubyEvalInteractiveRootNode(this, request.getSource()));
        } else {
            final RubyContext context = Objects.requireNonNull(getCurrentContext());
            return Truffle.getRuntime().createCallTarget(
                    new RubyParsingRequestNode(
                            this,
                            context,
                            request.getSource(),
                            request.getArgumentNames().toArray(StringUtils.EMPTY_STRING_ARRAY)));
        }
    }

    @Override
    protected ExecutableNode parse(InlineParsingRequest request) {
        final RubyContext context = Objects.requireNonNull(getCurrentContext());
        return new RubyInlineParsingRequestNode(this, context, request.getSource(), request.getFrame());
    }

    @SuppressWarnings("deprecation")
    @Override
    protected Object findExportedSymbol(RubyContext context, String symbolName, boolean onlyExplicit) {
        final Object explicit = context.getInteropManager().findExportedObject(symbolName);

        if (explicit != null) {
            return explicit;
        }

        if (onlyExplicit) {
            return null;
        }

        Object implicit = RubyContext.send(
                context.getCoreLibrary().truffleInteropModule,
                "lookup_symbol",
                symbolTable.getSymbol(symbolName));
        if (implicit == NotProvided.INSTANCE) {
            return null;
        } else {
            return implicit;
        }
    }

    @Override
    protected OptionDescriptors getOptionDescriptors() {
        return OptionDescriptors.create(Arrays.asList(OptionsCatalog.allDescriptors()));
    }

    @Override
    protected boolean isThreadAccessAllowed(Thread thread, boolean singleThreaded) {
        return true;
    }

    @Override
    protected void initializeThread(RubyContext context, Thread thread) {
        if (thread == context.getThreadManager().getOrInitializeRootJavaThread()) {
            // Already initialized when creating the context
            return;
        }

        if (context.getThreadManager().isRubyManagedThread(thread)) {
            // Already initialized by the Ruby-provided Runnable
            return;
        }

        final RubyThread foreignThread = context.getThreadManager().createForeignThread();
        context.getThreadManager().startForeignThread(foreignThread, thread);
    }

    @Override
    protected void disposeThread(RubyContext context, Thread thread) {
        if (thread == context.getThreadManager().getRootJavaThread()) {
            // Let the context shutdown cleanup the main thread
            return;
        }

        if (context.getThreadManager().isRubyManagedThread(thread)) {
            // Already disposed by the Ruby-provided Runnable
            return;
        }

        final RubyThread rubyThread = context.getThreadManager().getForeignRubyThread(thread);
        context.getThreadManager().cleanup(rubyThread, thread);
    }

    @Override
    protected Object getScope(RubyContext context) {
        return context.getTopScopeObject();
    }

    public String getTruffleLanguageHome() {
        return getLanguageHome();
    }

    @SuppressFBWarnings("IS2_INCONSISTENT_SYNC")
    public AllocationReporter getAllocationReporter() {
        return allocationReporter;
    }

    public ImmutableRubyString getFrozenStringLiteral(byte[] bytes, Encoding encoding, CodeRange codeRange) {
        return frozenStringLiterals.getFrozenStringLiteral(bytes, encoding, codeRange);
    }

    public ImmutableRubyString getFrozenStringLiteral(Rope rope) {
        return frozenStringLiterals.getFrozenStringLiteral(rope);
    }

    public long getNextObjectID() {
        final long id = nextObjectID.getAndAdd(ObjectSpaceManager.OBJECT_ID_INCREMENT_BY);

        if (id == ObjectSpaceManager.INITIAL_LANGUAGE_OBJECT_ID - ObjectSpaceManager.OBJECT_ID_INCREMENT_BY) {
            throw CompilerDirectives.shouldNotReachHere("Language Object IDs exhausted");
        }

        return id;
    }

    private static Shape createShape(Class<? extends RubyDynamicObject> layoutClass) {
        return Shape
                .newBuilder()
                .allowImplicitCastIntToLong(true)
                .layout(layoutClass)
                .dynamicType(RubyLanguage.objectType)
                .build();
    }

    @Override
    protected boolean areOptionsCompatible(OptionValues firstOptions, OptionValues newOptions) {
        return LanguageOptions.areOptionsCompatible(firstOptions, newOptions);
    }

}
