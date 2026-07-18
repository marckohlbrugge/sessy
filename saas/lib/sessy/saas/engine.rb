module Sessy
  module Saas
    class Engine < ::Rails::Engine
      initializer "sessy_saas.routes" do |app|
        app.routes.append do
          resource :saas_info, only: :show, controller: "sessy/saas/infos", path: "saas/info"
        end
      end

      config.to_prepare do
        ApplicationController.include Sessy::Saas::EditionHeaders
      end
    end
  end
end
