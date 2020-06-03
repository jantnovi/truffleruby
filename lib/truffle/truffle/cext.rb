# truffleruby_primitives: true

# Copyright (c) 2015, 2019 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

require_relative 'cext_ruby'
require_relative 'cext_constants'
require_relative 'cext_structs'

module Truffle::CExt
  DATA_TYPE = Primitive.object_hidden_var_create :data_type
  DATA_HOLDER = Primitive.object_hidden_var_create :data_holder
  DATA_MEMSIZER = Primitive.object_hidden_var_create :data_memsizer
  RB_TYPE = Primitive.object_hidden_var_create :rb_type
  ALLOCATOR_FUNC = Primitive.object_hidden_var_create :allocator_func

  extend self

  T_NONE     = 0x00

  T_OBJECT   = 0x01
  T_CLASS    = 0x02
  T_MODULE   = 0x03
  T_FLOAT    = 0x04
  T_STRING   = 0x05
  T_REGEXP   = 0x06
  T_ARRAY    = 0x07
  T_HASH     = 0x08
  T_STRUCT   = 0x09
  T_BIGNUM   = 0x0a
  T_FILE     = 0x0b
  T_DATA     = 0x0c
  T_MATCH    = 0x0d
  T_COMPLEX  = 0x0e
  T_RATIONAL = 0x0f

  T_NIL      = 0x11
  T_TRUE     = 0x12
  T_FALSE    = 0x13
  T_SYMBOL   = 0x14
  T_FIXNUM   = 0x15
  T_UNDEF    = 0x16

  T_IMEMO    = 0x1a
  T_NODE     = 0x1b
  T_ICLASS   = 0x1c
  T_ZOMBIE   = 0x1d

  T_MASK     = 0x1f

  RUBY_ENC_CODERANGE_UNKNOWN = 0
  RUBY_ENC_CODERANGE_7BIT = 1
  RUBY_ENC_CODERANGE_VALID = 2
  RUBY_ENC_CODERANGE_BROKEN = 4

  RUBY_ECONV_INVALID_MASK = Encoding::Converter::INVALID_MASK
  RUBY_ECONV_INVALID_REPLACE = Encoding::Converter::INVALID_REPLACE
  RUBY_ECONV_UNDEF_MASK = Encoding::Converter::UNDEF_MASK
  RUBY_ECONV_UNDEF_REPLACE = Encoding::Converter::UNDEF_REPLACE
  RUBY_ECONV_UNDEF_HEX_CHARREF = Encoding::Converter::UNDEF_HEX_CHARREF
  RUBY_ECONV_UNIVERSAL_NEWLINE_DECORATOR = Encoding::Converter::UNIVERSAL_NEWLINE_DECORATOR
  RUBY_ECONV_CRLF_NEWLINE_DECORATOR = Encoding::Converter::CRLF_NEWLINE_DECORATOR
  RUBY_ECONV_CR_NEWLINE_DECORATOR = Encoding::Converter::CR_NEWLINE_DECORATOR
  RUBY_ECONV_XML_TEXT_DECORATOR = Encoding::Converter::XML_TEXT_DECORATOR
  RUBY_ECONV_XML_ATTR_CONTENT_DECORATOR = Encoding::Converter::XML_ATTR_CONTENT_DECORATOR
  RUBY_ECONV_XML_ATTR_QUOTE_DECORATOR = Encoding::Converter::XML_ATTR_QUOTE_DECORATOR
  RUBY_ECONV_PARTIAL_INPUT = Encoding::Converter::PARTIAL_INPUT
  RUBY_ECONV_AFTER_OUTPUT = Encoding::Converter::AFTER_OUTPUT

  def supported?
    Interop.mime_type_supported?('application/x-sulong-library')
  end

  def rb_stdin
    $stdin
  end

  def rb_stdout
    $stdout
  end

  def rb_stderr
    $stderr
  end

  def rb_fs
    $;
  end

  def rb_output_fs
    $,
  end

  def rb_rs
    $/
  end

  def rb_output_rs
    $\
  end

  def rb_default_rs
    "\n"
  end

  def rb_to_symbol(name)
    case name
    when Symbol
      name
    else
      converted = Truffle::Type.rb_check_convert_type(name , String, :to_str)
      raise TypeError, "#{name} is not a symbol" unless converted
      converted.to_sym
    end
  end

  def rb_type(value)
    # TODO CS 23-Jul-16 we could do with making this a kind of specialising case
    # that puts never seen cases behind a transfer

    value_class = value.class
    type = Primitive.object_hidden_var_get(value_class, RB_TYPE)
    type ||= Primitive.object_hidden_var_set(value_class, RB_TYPE, rb_tr_find_type(value))
    rb_tr_cached_type(value, type)
  end

  def rb_tr_cached_type(value, type)
    if type == T_NONE
      if Primitive.object_hidden_var_get(value, DATA_HOLDER)
        T_DATA
      else
        T_OBJECT
      end
    elsif type == T_FIXNUM
      Truffle::Type.fits_into_long?(value) ? T_FIXNUM : T_BIGNUM
    else
      type
    end
  end

  def rb_tr_find_type(value)
    case value
    when Class
      T_CLASS
    when Module
      T_MODULE
    when Float
      T_FLOAT
    when String
      T_STRING
    when Regexp
      T_REGEXP
    when Array
      T_ARRAY
    when Hash
      T_HASH
    when Struct
      T_STRUCT
    when File
      T_FILE
    when Complex
      T_COMPLEX
    when Rational
      T_RATIONAL
    when NilClass
      T_NIL
    when TrueClass
      T_TRUE
    when FalseClass
      T_FALSE
    when Symbol
      T_SYMBOL
    when Integer
      # See #rb_tr_cached_type, the final type must be calculated for each number.
      T_FIXNUM
    when Time
      T_DATA
    when Data
      T_DATA
    when BasicObject
      # See #rb_tr_cached_type, the final type must be calculated for each object.
      T_NONE
    else
      raise "unknown type #{value.class}"
    end
  end

  def RB_TYPE_P(value, type)
    rb_type(value) == type
  end

  def rb_check_type(value, type)
    # TODO CS 23-Jul-16 there's more to this method than this...
    if rb_type(value) != type
      raise TypeError, "wrong argument type #{value.class.name} (expected #{type})"
    end
  end

  def ensure_class(obj, klass, message = 'expected class %s, but object class is %s')
    raise TypeError, format(message, klass, obj.class) unless obj.is_a? klass
  end

  def rb_method_boundp(klass, id, ex)
    if ex == 0
      (klass.method_defined?(id) || klass.private_method_defined?(id) || klass.protected_method_defined?(id)) ? 1 : 0
    else
      klass.method_defined?(id) ? 1 : 0
    end
  end

  def rb_obj_is_instance_of(object, ruby_class)
    object.class == ruby_class
  end

  def rb_obj_is_kind_of(object, ruby_class)
    object.kind_of?(ruby_class)
  end

  def SYMBOL_P(value)
    value.is_a?(Symbol)
  end

  def rb_to_int(val)
    Truffle::Type.rb_to_int(val)
  end

  def rb_fix2int(value)
    Primitive.rb_num2int(value)
  end

  def rb_fix2uint(value)
    Truffle::Type.rb_num2uint(value)
  end

  def rb_fix2str(value, base)
    value.to_s(base)
  end

  def RB_FIXNUM_P(value)
    Truffle::Type.fits_into_long?(value)
  end

  def RB_FLOAT_TYPE_P(value)
    value.is_a?(Float)
  end

  def rb_require(feature)
    require feature
  end

  def RB_OBJ_TAINTABLE(object)
    case object
    when TrueClass, FalseClass, NilClass, Integer, Float, Symbol
      false
    else
      true
    end
  end

  def rb_tr_obj_infect(dest, source)
    Primitive.infect(dest, source)
  end

  FREEZE_METHOD = Kernel.instance_method :freeze

  def rb_obj_freeze(obj)
    FREEZE_METHOD.bind(obj).call
  end

  def rb_float_new(value)
    value.to_f
  end

  def rb_absint_singlebit_p(val)
    Primitive.rb_int_singlebit_p(val.abs)
  end

  def rb_num2int(val)
    Primitive.rb_num2int(val)
  end

  def rb_num2long(val)
    Primitive.rb_num2long(val)
  end

  def rb_big2dbl(val)
    Truffle::Type.rb_big2dbl(val)
  end

  def rb_big2long(val)
    Truffle::Type.rb_big2long(val)
  end

  def rb_big2ulong(val)
    Truffle::Type.rb_big2long(val)
  end

  def rb_dbl2big(val)
    val.to_i
  end

  def rb_num_coerce_bin(x, y, func)
    a, b = do_coerce(x, y, true)
    a.__send__(func, b)
  end

  def rb_num_coerce_cmp(x, y, func)
    ary = do_coerce(x, y, false)
    if ary.nil?
      nil
    else
      a, b = ary
      a.__send__(func, b)
    end
  end

  def rb_num_coerce_relop(x, y, func)
    ary = do_coerce(x, y, false)
    unless ary.nil?
      a, b = ary
      res = a.__send__(func, b)
    end
    raise ArgumentError, "comparison of #{x.class} with #{y.class} failed" if res.nil?
    res
  end

  private def do_coerce(x, y, raise_error)
    unless y.respond_to?(:coerce)
      if raise_error
        raise TypeError, "#{y.class} can't be coerced to #{x.class}"
      else
        return nil
      end
    end

    ary = begin
      y.coerce(x)
    rescue
      if raise_error
        raise TypeError, "#{y.class} can't be coerced to #{x.class}"
      else
        warn 'Numerical comparison operators will no more rescue exceptions of #coerce'
        warn 'in the next release. Return nil in #coerce if the coercion is impossible.'
      end
      return nil
    end

    if !ary.is_a?(Array) || ary.size != 2
      if raise_error
        raise TypeError, 'coerce must return [x, y]'
      else
        warn 'Numerical comparison operators will no more rescue exceptions of #coerce'
        warn 'in the next release. Return nil in #coerce if the coercion is impossible.'
      end
      return nil
    end
    ary
  end

  def rb_num2uint(val)
    Truffle::Type.rb_num2uint(val)
  end

  def rb_num2ulong(val)
    # We're going to create a signed long here, and rely on the C to
    # cast it to an unsigned one.
    Truffle::Type.rb_num2ulong(val)
  end

  def rb_num2dbl(val)
    Truffle::Type.rb_num2dbl(val)
  end

  def rb_Integer(value)
    Integer(value)
  end

  def rb_Float(value)
    Float(value)
  end

  def RFLOAT_VALUE(value)
    value
  end

  def rb_hash_start(h)
    Primitive.vm_hash_start(h)
  end

  def rb_obj_classname(object)
    object.class.name
  end

  def rb_class_real(ruby_class)
    while ruby_class.singleton_class?
      ruby_class = ruby_class.superclass
    end

    ruby_class
  end

  def rb_obj_respond_to(object, id, priv)
    Primitive.object_respond_to?(object, id, priv != 0)
  end

  def rb_check_convert_type(obj, type_name, method)
    Truffle::Type.rb_check_convert_type(obj, Object.const_get(type_name), method.to_sym)
  end

  def rb_convert_type(obj, type_name, method)
    Truffle::Type.rb_convert_type(obj, Object.const_get(type_name), method.to_sym)
  end

  def rb_check_to_integer(obj, method)
    Truffle::Type.rb_check_to_integer(obj, method.to_sym)
  end

  def rb_obj_method_arity(object, id)
    object.method(id).arity
  end

  def rb_ivar_defined(object, id)
    Primitive.object_ivar_defined?(object, id)
  end

  def rb_f_global_variables
    Kernel.global_variables
  end

  def rb_obj_instance_variables(object)
    object.instance_variables
  end

  def rb_copy_generic_ivar(clone, original)
    Primitive.check_frozen clone
    original_ivars = original.instance_variables
    rb_free_generic_ivar(clone)
    original_ivars.each do |var|
      clone.instance_variable_set(var, original.instance_variable_get(var))
    end
  end

  def rb_free_generic_ivar(original)
    Primitive.check_frozen original
    original_ivars = original.instance_variables
    original_ivars.each do |var|
      original.__send__ :remove_instance_variable, var
    end
  end

  def rb_inspect(object)
    Truffle::Type.rb_inspect(object)
  end

  def rb_range_new(beg, last, exclude_end)
    Range.new(beg, last, exclude_end != 0)
  end

  def rb_reg_new(pattern, options)
    Regexp.new(pattern, options)
  end

  def rb_reg_new_str(str, options)
    Regexp.new(str, options)
  end

  def rb_marshal_dump(obj, port)
    Marshal.dump(obj, port)
  end

  def rb_marshal_load(port)
    Marshal.load(port)
  end

  def rb_reg_regcomp(str)
    Regexp.compile(str)
  end

  def rb_reg_match_pre(match)
    match.pre_match
  end

  def rb_reg_nth_match(nth, match)
    return nil if match.nil?
    match[nth]
  end

  def rb_reg_options(re)
    re.options
  end

  def ascii8bit_encoding
    Encoding::ASCII_8BIT
  end

  def usascii_encoding
    Encoding::US_ASCII
  end

  def utf8_encoding
    Encoding::UTF_8
  end

  def rb_default_external_encoding
    Encoding.find('external')
  end

  def rb_default_internal_encoding
    Encoding.find('internal')
  end

  def rb_locale_encoding
    Encoding::LOCALE
  end

  def rb_filesystem_encoding
    Encoding.filesystem
  end

  def rb_to_encoding_index(enc)
    enc = Truffle::Type.coerce_to_encoding(enc)
    return -1 if enc == false
    rb_enc_to_index(enc)
  end

  def rb_locale_encindex
    rb_enc_to_index Encoding::LOCALE
  end

  def rb_filesystem_encindex
    rb_enc_to_index Encoding.filesystem
  end

  def rb_ascii8bit_encindex
    rb_enc_to_index Encoding::ASCII_8BIT
  end

  def rb_usascii_encindex
    rb_enc_to_index Encoding::US_ASCII
  end

  def rb_utf8_encindex
    rb_enc_to_index Encoding::UTF_8
  end

  def rb_enc_from_index(index)
    Primitive.encoding_get_encoding_by_index index
  end

  def rb_enc_find_index(name)
    key = name.upcase.to_sym
    pair = Encoding::EncodingMap[key]
    if pair
      pair.last
    else
      -1
    end
  end

  def rb_enc_to_index(enc)
    Primitive.encoding_get_encoding_index enc
  end

  def rb_define_dummy_encoding(name)
    _, idx = Truffle::EncodingOperations.dummy_encoding(name)
    idx
  end

  def rb_str_new_frozen(value)
    if value.frozen?
      value
    else
      value.dup.freeze
    end
  end

  def rb_safe_level
    $SAFE
  end

  def rb_set_safe_level(level)
    $SAFE = level
  end

  def rb_set_safe_level_force(level)
    $SAFE = level
  end

  def rb_tracepoint_new(events, func, data)
    TracePoint.new(*events_to_events_array(events)) do |tp|
      Primitive.call_with_c_mutex(func, [tp, data])
    end
  end

  def events_to_events_array(events)
    events_ary = []
    if events.anybits? 0x0001
      events ^= 0x0001
      events_ary << :line
    end
    if events.anybits? 0x0002
      events ^= 0x0002
      events_ary << :class
    end

    if events.anybits? 0x100000
      events ^= 0x100000
      warn 'warning: rb_tracepoint_new(RUBY_INTERNAL_EVENT_NEWOBJ) is not yet implemented' if $VERBOSE
      events_ary << :never
    end
    if events.anybits? 0x200000
      events ^= 0x200000
      warn 'warning: rb_tracepoint_new(RUBY_INTERNAL_EVENT_FREEOBJ) is not yet implemented' if $VERBOSE
      events_ary << :never
    end

    raise ArgumentError, "unknown event #{'%#x' % events}" unless events == 0
    events_ary
  end

  def rb_thread_alone
    Thread.list.count == 1 ? 1 : 0
  end

  def rb_intern(str)
    str.intern
  end

  def rb_int_positive_pow(a, b)
    a ** b
  end

  def rb_cstr_to_inum(string, base, raise)
    Primitive.string_to_inum string, base, raise != 0, true
  end

  def rb_cstr_to_dbl(string, badcheck)
    result = Primitive.string_to_f string
    if result.nil?
      if badcheck
        raise ArgumentError, "invalid value for Float(): #{string.inspect}"
      else
        0.0
      end
    else
      result
    end
  end

  def rb_str_new_native(pointer, length)
    raise "#{pointer} not a pointer" unless Truffle::Interop.pointer?(pointer)
    Truffle::FFI::Pointer.new(pointer).read_string(length).untaint
  end

  def rb_enc_str_coderange(str)
    cr = Primitive.string_get_coderange str
    coderange_java_to_rb(cr)
  end

  def coderange_java_to_rb(cr)
    case cr
    when 0
      RUBY_ENC_CODERANGE_UNKNOWN
    when 1
      RUBY_ENC_CODERANGE_7BIT
    when 2
      RUBY_ENC_CODERANGE_VALID
    when 3
      RUBY_ENC_CODERANGE_BROKEN
    else
      raise "Cannot convert coderange #{cr} to rb code range"
    end
  end

  def RB_ENC_CODERANGE(obj)
    if obj.is_a? String
      rb_enc_str_coderange(obj)
    else
      raise "Unknown coderange for obj with class `#{obj.class}`"
    end
  end

  def rb_enc_associate_index(obj, idx)
    enc = rb_enc_from_index(idx)
    case obj
    when String
      obj.force_encoding(enc)
    else
      raise "rb_enc_associate_index not implemented for class `#{obj.class}`"
    end
  end

  def rb_enc_set_index(obj, idx)
    enc = rb_enc_from_index(idx)
    case obj
    when String
      obj.force_encoding enc
    else
      obj.instance_variable_set :@encoding, enc
    end
  end

  def rb_enc_get(obj)
    case obj
    when Encoding
      obj
    when Symbol
      obj.encoding
    when String
      obj.encoding
    when Regexp
      obj.encoding
    else
      obj.instance_variable_get :@encoding
    end
  end

  def rb_enc_get_index(obj)
    enc = case obj
          when Symbol
            obj.encoding
          when String
            obj.encoding
          when Regexp
            obj.encoding
          when File
            obj.internal_encoding || obj.external_encoding
          when NilClass, Integer, Float, TrueClass, FalseClass
            -1
          # TODO BJF Mar-9-2017 Handle T_DATA
          else
            if obj.instance_variable_defined?(:@encoding)
              obj.instance_variable_get(:@encoding)
            else
              0
            end
          end
    enc = rb_enc_to_index(enc) if enc.is_a?(Encoding)
    enc
  end

  def rb_intern_str(string)
    string.intern
  end

  def rb_intern3(string, enc)
    string.force_encoding(enc).intern
  end

  def rb_str_append(str, to_append)
    str.append(to_append)
  end

  def rb_str_concat(str, to_concat)
    str << to_concat
  end

  def rb_str_encode(str, to, ecflags, ecopts)
    opts = {}
    opts.merge!(ecopts) unless ecopts.nil?

    # TODO BJF 8-Mar-2017 Handle more ecflags
    if ecflags & Encoding::Converter::INVALID_REPLACE != 0
      opts[:invalid] = :replace
    end

    if opts.empty?
      str.encode(to)
    else
      str.encode(to, opts)
    end
  end

  def rb_str_conv_enc_opts(str, from, to, ecflags, ecopts)
    if (to.ascii_compatible? && str.ascii_only?) || to == Encoding::ASCII_8BIT || to.dummy?
      if str.encoding != to
        str = str.dup
        str.force_encoding(to)
      end
      return str
    end

    ec = Encoding::Converter.new(from, to, ecopts || ecflags)
    dest = ''
    # This C API will (unlike primitive convert) not alter the source
    # string, so we need to duplicate it.
    status = ec.primitive_convert str.dup, dest, nil, nil, ec.options
    status == :finished ? dest : str
  end

  def rb_cmpint(val, a, b)
    raise ArgumentError, "comparison of #{a.class} and #{b.class} failed" if val.nil?
    if val > 0
      1
    elsif val < 0
      -1
    else
      0
    end
  end

  def rb_funcall_with_block(recv, meth, args, block)
    recv.public_send(meth, *args, &block)
  end

  def rb_respond_to(object, name)
    object.respond_to?(name)
  end

  def rb_funcallv_public(recv, meth, args)
    recv.public_send(meth, *args)
  end

  def rb_funcallv(recv, meth, args)
    rb_funcall(recv, meth, nil, *args)
  end

  def rb_funcall(recv, meth, n, *args)
    # see #call_with_thread_locally_stored_block
    thread_local_block = Thread.current[:__C_BLOCK__]
    Thread.current[:__C_BLOCK__] = nil
    recv.__send__(meth, *args, &thread_local_block)
  ensure
    Thread.current[:__C_BLOCK__] = thread_local_block
  end

  def rb_apply(recv, meth, args)
    recv.__send__(meth, *args)
  end

  def rb_define_attr(klass, name, read, write)
    if read != 0 && write != 0
      klass.class_eval { attr_accessor name }
    elsif read != 0
      klass.class_eval { attr_reader name }
    elsif write != 0
      klass.class_eval { attr_writer name }
    end
  end

  def rb_make_backtrace
    caller
  end

  def rb_string_value_cstr_check(string)
    raise ArgumentError, 'string contains null byte' if string.include?(0.chr(string.encoding))
  end

  def rb_String(value)
    String(value)
  end

  def rb_Array(value)
    Array(value)
  end

  def rb_Hash(value)
    Hash(value)
  end

  def rb_ary_new
    []
  end

  def rb_ary_new_capa(capacity)
    if capacity < 0
      raise ArgumentError, 'negative array size (or size too big)'
    end
    []
  end

  def rb_hash_new
    {}
  end

  def rb_ident_hash_new
    {}.compare_by_identity
  end

  def rb_hash_set_ifnone(hash, value)
    hash.default = value
  end

  ST_CONTINUE = 0
  ST_STOP = 1
  ST_DELETE = 2

  def rb_hash_foreach(hash, func, farg)
    hash.each do |key, value|
      st_result = Truffle::Interop.execute_without_conversion(func, Primitive.cext_wrap(key), Primitive.cext_wrap(value), farg)

      case st_result
      when ST_CONTINUE
      when ST_STOP then break
      when ST_DELETE then hash.delete(key)
      else raise ArgumentError, "Unknown 'func' return value: #{st_result}"
      end
    end
  end

  def rb_path_to_class(path)
    begin
      const = Object.const_get(path, false)
    rescue NameError
      raise ArgumentError, "undefined class/module #{path}"
    end
    raise TypeError unless const.is_a?(Class)
    const
  end

  def rb_proc_new(function, value)
    Proc.new do |*args|
      Primitive.cext_unwrap(
          Primitive.call_with_c_mutex(function, [
              Primitive.cext_wrap(args.first), # yieldarg
              nil, # procarg,
              0, # argc
              nil, # argv
              nil, # blockarg
          ]))
    end
  end

  def rb_proc_call(prc, args)
    prc.call(*args)
  end

  # The idea of rb_protect and rb_jump_tag is to avoid unwinding the
  # native stack in an uncontrolled manner. To do this we need to be
  # able to run a piece of code and capture both its result (if it
  # produces one), and any exception it generates. This is done by
  # running the requested code in a block as follows
  #
  #   e = store_exception { res = requested_function(...) }
  #
  # leaving us with e containing any exception thrown from the block,
  # and res containing the result of the function if it completed
  # successfully. Since Ruby's API only allows us to use a number to
  # indicate there was an exception we have to store it in a thread
  # local array and provide a 1-based index into that array. Then once
  # the native library has unwound its own stack by whatever method,
  # and can allow the ruby error to propagate, it can call rb_jump_tag
  # with the integer produced by rb_protect. rb_jump_tag then gets the
  # exception out of the thread local and calls raise exception to
  # throw it and allow normal error handling to continue.

  def rb_protect(function, arg, write_status, status)
    # We wrap nil here to avoid wrapping any result returned, as the
    # function called will do that. In general we try not to touch the
    # values passed in or out of protected functions as C extensions
    # may accept or return arbitrary pointers rather than ruby VALUEs.
    res = Primitive.cext_wrap(nil)
    pos = 0
    e = capture_exception do
      res = Truffle::Interop.execute_without_conversion(function, arg)
    end

    unless Primitive.object_equal(nil, e)
      store = (Thread.current[:__stored_exceptions__] ||= [])
      pos = store.push(e).size
    end

    Truffle::Interop.execute_without_conversion(write_status, status, pos)
    res
  end

  def rb_jump_tag(pos)
    if pos > 0
      store = Thread.current[:__stored_exceptions__]
      if pos == store.size
        e = store.pop
      else
        # Can't disturb other positions or other rb_jump_tag calls might fail.
        e = store[pos - 1]
        store[pos - 1] = nil
      end
      raise_exception(e)
    end
  end

  def rb_yield(value)
    Primitive.call_with_c_mutex(rb_block_proc, [value])
  end

  def rb_yield_splat(values)
    Primitive.call_with_c_mutex(rb_block_proc, values)
  end

  def rb_ivar_lookup(object, name, default_value)
    # TODO CS 24-Jul-16 races - needs a new primitive or be defined in Java?
    if Primitive.object_ivar_defined?(object, name)
      Primitive.object_ivar_get(object, name)
    else
      default_value
    end
  end

  def rb_cvar_defined(cls, id)
    id_s = id.to_s
    if id_s.start_with?('@@') || !id_s.start_with?('@')
      cls.class_variable_defined?(id)
    else
      cls.instance_variable_defined?(id)
    end
  end

  def rb_cv_get(cls, name)
    cls.class_variable_get(name.to_sym)
  end

  def rb_cv_set(cls, name, val)
    cls.class_variable_set(name.to_sym, val)
  end

  def rb_cvar_get(cls, id)
    cls.class_variable_get(id)
  end

  def rb_cvar_set(cls, id, val)
    cls.class_variable_set(id, val)
  end

  def rb_exc_raise(exception)
    raise exception
  end

  def rb_set_errinfo(error)
    Truffle::Type.set_last_exception(error)
  end

  def rb_errinfo
    $!
  end

  def rb_check_arity(arg_count, min, max)
    Truffle::Type.check_arity arg_count, min, max
  end

  def rb_arity_error_string(arg_count, min, max)
    Truffle::Type.arity_error_string(arg_count, min, max)
  end

  def rb_raise(object, name)
    raise 'not implemented'
  end

  def rb_ivar_get(object, name)
    Primitive.object_ivar_get object, name
  end

  def rb_ivar_set(object, name, value)
    Primitive.object_ivar_set object, name, value
  end

  def rb_special_const_p(object)
    Truffle::Type.is_special_const?(object)
  end

  def rb_id2str(sym)
    sym.to_s
  end

  def rb_define_class_under(mod, name, superclass)
    # nil is TypeError (checked below), false is ArgumentError
    if false.equal?(superclass)
      raise ArgumentError, "no super class for `#{name}'"
    end

    if mod.const_defined?(name, false)
      current_class = mod.const_get(name, false)
      unless current_class.class == Class
        raise TypeError, "#{mod}::#{name} is not a class"
      end
      if superclass != current_class.superclass
        raise TypeError, "superclass mismatch for class #{name}"
      end
      current_class
    else
      mod.const_set name, Class.new(superclass)
    end
  end

  def rb_define_module_under(mod, name)
    if mod.const_defined?(name, false)
      val = mod.const_get(name, false)
      unless val.class == Module
        raise TypeError, "#{mod}::#{name} is not a module"
      end
      val
    else
      mod.const_set name, Module.new
    end
  end

  def rb_define_method_undefined(mod, name)
    mod.define_method(name) do |*|
      raise NotImplementedError, "#{name}() function is unimplemented on this machine"
    end
  end

  def rb_class_new_instance(klass, args)
    klass.new(*args)
  end

  def rb_f_sprintf(args)
    sprintf(*args)
  end

  def rb_io_printf(out, args)
    out.printf(*args)
  end

  def rb_io_print(out, args)
    Truffle::IOOperations.print out, args, nil
  end

  def rb_io_puts(out, args)
    Truffle::IOOperations.puts out, args
  end

  def rb_equal(a, b)
    Primitive.object_same_or_equal(a, b)
  end

  def rb_obj_call_init(obj, args)
    obj.__send__ :initialize, *args
  end

  def rb_obj_instance_eval(obj, args, block)
    obj.instance_eval(*args, &block)
  end

  def rb_enumeratorize(obj, meth, args)
    obj.to_enum(meth, *args)
  end

  def rb_enumeratorize_with_size(obj, meth, args, size_fn)
    return rb_enumeratorize(obj, meth, args) if size_fn.nil?
    enum = obj.to_enum(meth, *args) { Primitive.cext_unwrap(Primitive.call_with_c_mutex(size_fn, [Primitive.cext_wrap(obj), Primitive.cext_wrap(args), Primitive.cext_wrap(enum)])) }
    enum
  end

  def rb_eval_string(str)
    eval(str)
  end

  def rb_newobj_of(ruby_class)
    ruby_class.__send__(:__layout_allocate__)
  end

  def rb_define_alloc_func(ruby_class, function)
    ruby_class.singleton_class.define_method(:__allocate__) do
      Primitive.cext_unwrap(Primitive.call_with_c_mutex(function, [Primitive.cext_wrap(self)]))
    end
    class << ruby_class
      private :__allocate__
    end
    Primitive.object_hidden_var_set(ruby_class.singleton_class, ALLOCATOR_FUNC, function)
  end

  def rb_get_alloc_func(ruby_class)
    return nil unless Class === ruby_class
    begin
      allocate_method = ruby_class.method(:__allocate__).owner
    rescue NameError
      nil
    else
      Primitive.object_hidden_var_get(allocate_method, ALLOCATOR_FUNC)
    end
  end

  def rb_undef_alloc_func(ruby_class)
    ruby_class.singleton_class.send(:undef_method, :__allocate__)
  rescue NameError
    nil # it's fine to call this on a class that doesn't have an allocator
  else
    Primitive.object_hidden_var_set(ruby_class.singleton_class, ALLOCATOR_FUNC, nil)
  end

  def rb_alias(mod, new_name, old_name)
    mod.send(:alias_method, new_name, old_name)
  end

  def rb_undef(mod, name)
    if mod.frozen? or mod.method_defined?(name) or mod.private_method_defined?(name)
      mod.send(:undef_method, name)
    end
  end

  def rb_attr(ruby_class, name, read, write, ex)
    if ex.zero?
      private = false
      protected = false
      module_function = false
    else
      private = caller_frame_visibility(:private)
      protected = caller_frame_visibility(:protected)
      module_function = caller_frame_visibility(:module_function)
    end

    if read
      ruby_class.class_exec do
        attr_reader name
        private name if private
        protected name if protected
        module_function name if module_function
      end
    end

    if write
      ruby_class.class_exec do
        attr_writer name
        setter_name = :"#{name}="
        private setter_name if private
        protected setter_name if protected
        module_function setter_name if module_function
      end
    end
  end

  def rb_Rational(num, den)
    Rational.new(num, den)
  end

  def rb_rational_raw(num, den)
    Rational.new(num, den)
  end

  def rb_rational_new(num, den)
    Rational(num, den)
  end

  def rb_Complex(real, imag)
    Complex.new(real, imag)
  end

  def rb_complex_raw(real, imag)
    Complex.new(real, imag)
  end

  def rb_complex_new(real, imag)
    Complex(real, imag)
  end

  def rb_complex_polar(r, theta)
    Complex.new(r, theta)
  end

  def rb_complex_set_real(complex, real)
    complex.__send__ :real=, real
  end

  def rb_complex_set_imag(complex, imag)
    complex.__send__ :imag=, imag
  end

  def rb_mutex_new
    Mutex.new
  end

  def rb_mutex_locked_p(mutex)
    mutex.locked?
  end

  def rb_mutex_trylock(mutex)
    mutex.try_lock
  end

  def rb_mutex_lock(mutex)
    mutex.lock
  end

  def rb_mutex_unlock(mutex)
    mutex.unlock
  end

  def rb_mutex_sleep(mutex, timeout)
    mutex.sleep(timeout)
  end

  def rb_mutex_synchronize(mutex, func, arg)
    mutex.synchronize do
      Primitive.cext_unwrap(Primitive.call_with_c_mutex(func, [Primitive.cext_wrap(arg)]))
    end
  end

  def rb_gc_enable
    GC.enable
  end

  def rb_gc_disable
    GC.disable
  end

  def rb_gc
    GC.start
  end

  GC_ROOTS = []

  def rb_gc_register_mark_object(obj)
    GC_ROOTS.push obj
  end

  def rb_gc_latest_gc_info(hash_or_key)
    case hash_or_key
    when Symbol
      if hash_or_key == :state
        :none
      else
        raise ArgumentError, "unknown key: #{hash_or_key}"
      end
    when Hash
      hash_or_key[:state] = :none
      hash_or_key
    else
      raise TypeError, 'non-hash or symbol given'
    end
  end

  def rb_nativethread_self
    Thread.current
  end

  NATIVETHREAD_LOCKS = {}

  def rb_nativethread_lock_initialize
    lock = Mutex.new
    NATIVETHREAD_LOCKS[lock] = nil
    lock
  end

  def rb_nativethread_lock_destroy(lock)
    NATIVETHREAD_LOCKS.delete(lock)
  end

  def rb_set_end_proc(func, data)
    at_exit { Primitive.call_with_c_mutex(func, [data]) }
  end

  def rb_data_object_wrap(ruby_class, data, mark, free)
    ruby_class = Object unless ruby_class
    object = ruby_class.__send__(:__layout_allocate__)
    data_holder = DataHolder.new(data)
    Primitive.object_hidden_var_set object, DATA_HOLDER, data_holder
    ObjectSpace.define_finalizer object, data_finalizer(free, data_holder) unless free.nil?
    define_marker object, data_marker(mark, data_holder) unless mark.nil?
    object
  end

  def rb_data_typed_object_wrap(ruby_class, data, data_type, mark, free, size)
    ruby_class = Object unless ruby_class
    object = ruby_class.__send__(:__layout_allocate__)
    data_holder = DataHolder.new(data)
    Primitive.object_hidden_var_set object, DATA_TYPE, data_type
    Primitive.object_hidden_var_set object, DATA_HOLDER, data_holder
    Primitive.object_hidden_var_set object, DATA_MEMSIZER, data_sizer(size, data_holder) unless size.nil?

    ObjectSpace.define_finalizer object, data_finalizer(free, data_holder) unless free.nil?

    define_marker object, data_marker(mark, data_holder) unless mark.nil?
    object
  end

  # These data function are created in separate methods to ensure they
  # will not accidentally capture the objects they operate on, which
  # might prevent garbage collection.
  def data_finalizer(free, data_holder)
    raise unless free.respond_to?(:call)
    proc {
      Primitive.call_with_c_mutex(free, [data_holder.data]) unless Truffle::Interop.null?(data_holder.data)
    }
  end

  def data_marker(mark, data_holder)
    raise unless mark.respond_to?(:call)
    proc { |obj|
      create_mark_list(obj)
      Primitive.call_with_c_mutex(mark, [data_holder.data]) unless Truffle::Interop.null?(data_holder.data)
      set_mark_list_on_object(obj)
    }
  end

  def data_sizer(sizer, data_holder)
    raise unless sizer.respond_to?(:call)
    proc {
      Primitive.call_with_c_mutex(sizer, [data_holder.data])
    }
  end

  def rb_ruby_verbose_ptr
    $VERBOSE
  end

  def rb_ruby_debug_ptr
    $DEBUG
  end

  def rb_tr_error(message)
    Truffle::KernelOperations.internal_raise RuntimeError, message, nil, true
  end

  def test_kwargs(kwargs, raise_error)
    return false if kwargs.nil?

    if kwargs.is_a?(Hash) && kwargs.keys.all? { |k| k.is_a?(Symbol) }
      true
    elsif raise_error
      raise ArgumentError, "the value is not a Hash with all keys being Symbols as kwargs requires: #{kwargs}"
    else
      false
    end
  end

  def send_splatted(object, method, args)
    object.__send__(method, *args)
  end

  def rb_block_call(object, method, args, func, data)
    object.__send__(method, *args) do |*block_args|
      Primitive.cext_unwrap(Primitive.call_with_c_mutex(func, [
          Primitive.cext_wrap(block_args.first),
          data,
          block_args.size, # argc
          Truffle::CExt.RARRAY_PTR(block_args), # argv
          nil, # blockarg
      ]))
    end
  end

  def rb_module_new
    Module.new
  end

  def rb_ensure(b_proc, data1, e_proc, data2)
    begin
      Primitive.call_with_c_mutex(b_proc, [data1])
    ensure
      Primitive.call_with_c_mutex(e_proc, [data2])
    end
  end

  def rb_rescue(b_proc, data1, r_proc, data2)
    begin
      Primitive.call_with_c_mutex(b_proc, [data1])
    rescue StandardError => e
      if Truffle::Interop.null?(r_proc)
        Primitive.cext_wrap(nil)
      else
        Primitive.call_with_c_mutex(r_proc, [data2, Primitive.cext_wrap(e)])
      end
    end
  end

  def rb_rescue2(b_proc, data1, r_proc, data2, rescued)
    begin
      Primitive.call_with_c_mutex(b_proc, [data1])
    rescue *rescued => e
      Primitive.call_with_c_mutex(r_proc, [data2, Primitive.cext_wrap(e)])
    end
  end

  def rb_exec_recursive(func, obj, arg)
    result = nil

    recursive = Thread.detect_recursion(obj) do
      result = Primitive.cext_unwrap(Primitive.call_with_c_mutex(func, [Primitive.cext_wrap(obj), Primitive.cext_wrap(arg), 0]))
    end

    if recursive
      Primitive.cext_unwrap(Primitive.call_with_c_mutex(func, [Primitive.cext_wrap(obj), Primitive.cext_wrap(arg), 1]))
    else
      result
    end
  end

  def rb_catch_obj(tag, func, data)
    catch tag do |caught|
      Primitive.cext_unwrap(Primitive.call_with_c_mutex(func, [
          Primitive.cext_wrap(caught),
          Primitive.cext_wrap(data),
          0, # argc
          nil, # argv
          nil, # blockarg
      ]))
    end
  end

  def rb_memerror
    raise NoMemoryError, 'failed to allocate memory'
  end

  def rb_struct_define_no_splat(name, attrs)
    Struct.new(name, *attrs)
  end

  def rb_struct_define_under_no_splat(outer, name, attrs)
    struct = Struct.new(nil, *attrs)
    rb_const_set outer, name, struct
    struct
  end

  def rb_struct_aref(struct, index)
    struct[index]
  end

  def rb_struct_aset(struct, index, value)
    struct[index] = value
  end

  def rb_struct_size(klass)
    klass.members.size
  end

  def rb_struct_new_no_splat(klass, args)
    klass.new(*args)
  end

  def yield_no_block
    raise LocalJumpError
  end

  def warn?
    !$VERBOSE.nil?
  end

  def warning?
    # has to return true or false
    true == $VERBOSE
  end

  def rb_time_nano_new(sec, nsec)
    Time.at sec, Rational(nsec, 1000)
  end

  def rb_time_timespec_new(sec, nsec, offset, is_utc, is_local)
    time = rb_time_nano_new(sec, nsec)
    return time if is_local
    return time.getgm if is_utc
    time.getlocal(offset)
  end

  def rb_time_num_new(timev, off)
    Time.at(timev).getlocal(off)
  end

  def rb_time_interval_acceptable(time_val)
    # TODO (pitr-ch 09-Mar-2017): more precise error messages
    raise TypeError, 'cannot be Time' if time_val.is_a? Time
    raise ArgumentError, 'cannot be negative' if time_val < 0
  end

  def rb_thread_create(fn, args)
    Thread.new do
      Primitive.call_with_c_mutex(fn, [args])
    end
  end

  def rb_thread_call_with_gvl(function, data)
    Primitive.call_with_c_mutex(function, [data])
  end

  def rb_thread_call_without_gvl(function, data1, unblock, data2)
    if unblock
      unblocker = -> {
        Truffle::Interop.execute_without_conversion(unblock, data2)
      }
    end

    Primitive.call_without_c_mutex(
        -> { Thread.current.unblock(
            unblocker,
            -> { function.call(data1) }) }, [])
  end

  def rb_iterate(iteration, iterated_object, callback, callback_arg)
    block = rb_block_proc
    if block
      call_with_thread_locally_stored_block iteration, iterated_object do |block_arg|
        rb_iterate_call_block(callback, block_arg, callback_arg, &block)
      end
    else
      call_with_thread_locally_stored_block iteration, iterated_object do |block_arg|
        Primitive.cext_unwrap(Primitive.call_with_c_mutex(callback, [
            Primitive.cext_wrap(block_arg),
            Primitive.cext_wrap(callback_arg),
            0, # argc
            nil, # argv
            nil, # blockarg
        ]))
      end
    end
  end

  def rb_thread_wait_fd(fd)
    io = IO.for_fd(fd)
    io.autoclose = false
    Primitive.call_without_c_mutex(IO.method(:select), [[io]])
    nil
  end

  def rb_thread_fd_writable(fd)
    io = IO.for_fd(fd)
    io.autoclose = false
    _r, w, _e = Primitive.call_without_c_mutex(IO.method(:select), [nil, [io]])
    w.size
  end

  # From ruby.h
  RB_WAITFD_IN = 1
  RB_WAITFD_PRI = 2
  RB_WAITFD_OUT = 4

  def rb_wait_for_single_fd(fd, events, tv_secs, tv_usecs)
    io = IO.for_fd(fd)
    io.autoclose = false
    read = (events & RB_WAITFD_IN) != 0 ? [io] : nil
    write = (events & RB_WAITFD_OUT) != 0 ? [io] : nil
    error = (events & RB_WAITFD_PRI) != 0 ? [io] : nil
    timeout = nil
    if tv_secs >= 0 || tv_usecs >= 0
      timeout = tv_secs + tv_usecs/1.0e6
    end
    r, w, e = Primitive.call_without_c_mutex(IO.method(:select), [read, write, error, *timeout])
    if r.nil? # timeout
      0
    else
      result = 0
      result |= RB_WAITFD_IN unless r.empty?
      result |= RB_WAITFD_OUT unless w.empty?
      result |= RB_WAITFD_PRI unless e.empty?
      result
    end
  end

  def rb_call_super(args)
    rb_call_super_splatted(*args)
  end

  def rb_any_to_s(object)
    Truffle::Type.rb_any_to_s(object)
  end

  def rb_obj_as_string(object)
    Truffle::Type.rb_obj_as_string(object)
  end

  def rb_class_inherited_p(ruby_module, object)
    if object.is_a?(Module)
      ruby_module <= object
    else
      raise TypeError
    end
  end

  def rb_tr_readable(mode)
    mode == File::Constants::RDONLY || mode == File::Constants::RDWR
  end

  def rb_tr_writable(mode)
    mode == File::Constants::WRONLY || mode == File::Constants::RDWR
  end

  def rb_backref_get
    Truffle::RegexpOperations.last_match(
      Truffle::ThreadOperations.ruby_caller([Truffle::CExt, Truffle::Interop.singleton_class]))
  end

  def rb_gv_set(name, value)
    binding.eval("#{name} = value")
  end

  def rb_gv_get(name)
    name = "$#{name}" unless name.to_s.start_with?('$')
    if name == '$~'
      rb_backref_get
    else
      eval("#{name}")
    end
  end

  def rb_reg_match(re, str)
    re =~ str
  end

  def rb_hash_aref(object, key)
    object[key]
  end

  def rb_define_hooked_variable(name, gvar, getter, setter)
    name = "$#{name}" unless name.start_with?('$')
    id = name.to_sym

    getter_proc = -> {
      Primitive.cext_unwrap(Primitive.call_with_c_mutex(getter, [Primitive.cext_wrap(id), gvar, Primitive.cext_wrap(nil)]))
    }

    setter_proc = -> value {
      Primitive.call_with_c_mutex(setter, [Primitive.cext_wrap(value), Primitive.cext_wrap(id), gvar, Primitive.cext_wrap(nil)])
    }

    Truffle::KernelOperations.define_hooked_variable id, getter_proc, setter_proc
  end

  LOG_WARNING = Truffle::Boot.get_option 'cexts-log-warnings'

  def rb_tr_log_warning(message)
    Truffle::Debug.log_warning message if LOG_WARNING
  end

  def rb_convert_to_encoding(encoding)
    if Encoding === encoding
      encoding
    else
      Encoding.find(encoding.to_str)
    end
  end

  def rb_to_encoding(encoding)
    RbEncoding.get(encoding)
  end

  def GetOpenFile(io)
    RbIO.new(io)
  end

  def rb_enc_from_encoding(rb_encoding)
    rb_encoding.encoding
  end

  def rb_enc_from_native_encoding(rb_encoding)
    RbEncoding.get_encoding_from_native(rb_encoding)
  end

  def native_string?(string)
    Primitive.string_is_native?(string)
  end

  def NATIVE_RSTRING_PTR(string)
    Primitive.string_pointer_to_native(string)
  end

  def rb_java_class_of(object)
    Truffle::Debug.java_class_of(object)
  end

  def rb_java_to_string(object)
    Truffle::Interop.to_string(object)
  end

  def rb_sprintf(format, *args)
    # TODO (kjmenard 19-May-17) We shouldn't just ignore the '+' modifier. This is a hack to just get things running, even if it produces bad data.
    f = format.gsub(/%(?:\+)?l.\v/, '%s')

    # TODO (kjmenard 30-Oct-17) Deal with this hack better. Ruby's `sprintf` doesn't understand the '%l' modifier. But Ruby also doesn't delineate between 32-bit and 64-bit integers, so stripping out the modifier should be fine.
    f = f.gsub('%ld', '%d')

    sprintf(f, *args) rescue raise ArgumentError, "Bad format string #{f}."
  end

  def test_cext_wrap(value)
    Primitive.cext_wrap(value)
  end
end
