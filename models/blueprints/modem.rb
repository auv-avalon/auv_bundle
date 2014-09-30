require 'models/blueprints/localization'
using_task_library 'modemdriver'

module Modem
    class ModemCmp < Syskit::Composition
        add_main ::Dev::ASVModem, as: 'main'

    end
end
