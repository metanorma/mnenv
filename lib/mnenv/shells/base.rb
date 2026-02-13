# frozen_string_literal: true

module Mnenv
  module Shells
    # Base class for shell-specific behavior
    class BaseShell
      def name
        raise NotImplementedError
      end

      def shim_extension
        raise NotImplementedError
      end

      def shim_content(executable_name)
        raise NotImplementedError
      end

      def use_output(version, source)
        raise NotImplementedError
      end

      def config_file
        raise NotImplementedError
      end

      def windows?
        false
      end
    end
  end
end
