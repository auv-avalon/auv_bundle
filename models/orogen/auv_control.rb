require 'models/blueprints/avalon'
    
Base::ControlLoop.declare 'WorldXYZRollPitchYaw', '/base/LinearAngular6DCommand'
Base::ControlLoop.declare 'WorldZRollPitchYaw', '/base/LinearAngular6DCommand'
Base::ControlLoop.declare 'XYVelocity', '/base/LinearAngular6DCommand'

class AuvControl::ConstantCommand
    provides Base::WorldXYZRollPitchYawControllerSrv, :as => 'world_cmd'
end
