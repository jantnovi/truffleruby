# Copyright (c) 2018 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 1.0
# GNU General Public License version 2
# GNU Lesser General Public License version 2.1

module Truffle
  module KernelOperations
    def self.define_hooked_variable(name, getter, setter)
      define_hooked_variable_with_is_defined(name, getter, setter, proc { 'global-variable' } )
    end
  end
end
