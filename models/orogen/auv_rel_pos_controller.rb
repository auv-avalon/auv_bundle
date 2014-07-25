require 'models/blueprints/auv'

class AuvRelPosController::Task
    provides Base::AUVRelativeMotionControlledSystemSrv, :as => "controlled_system"
    provides Base::AUVMotionControllerSrv, :as => "controller"
end



