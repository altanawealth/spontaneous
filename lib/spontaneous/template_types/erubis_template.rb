module Spontaneous
  module TemplateTypes
    class ErubisTemplate < Template
      def render(binding)
        template.result(binding)
      end

      def template
        @template ||= Erubis::Eruby.new(File.read(path))
      end
    end
  end
end
