# encoding: UTF-8

module Spontaneous
  module Rack
    POWERED_BY = {
      "X-Powered-By" => "Spontaneous CMS v#{Spontaneous::VERSION}"
    }

    class AroundFront
      def initialize(app)
        @app = app
        @renderer = Spontaneous::Output.published_renderer
      end

      def call(env)
        status = headers = body = nil
        env[Rack::RENDERER] = @renderer
        Content.with_identity_map do
          Site.with_published do
            status, headers, body = @app.call(env)
          end
        end
        [status, headers.merge(POWERED_BY), body]
      end
    end

  end
end

