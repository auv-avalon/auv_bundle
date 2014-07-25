require 'models/blueprints/avalon'

class AvalonControl::FakeWriter
    attr_reader :options

    def configure
        super
        return if(!@options)
        update_config(@options)
    end

    def update_config(options)
        @options = options
        Robot.info "Starting real task with options: #{@options}"
        orocos_task.speed_x = @options[:speed_x] if @options[:speed_x]
        orocos_task.speed_y = @options[:speed_y] if @options[:speed_y]
        orocos_task.Z = @options[:depth] if @options[:depth]
        orocos_task.heading = @options[:heading] if @options[:heading]
        return true
    end


        
    provides Base::AUVMotionControllerSrv, :as => "controller"
end

class AvalonControl::RelFakeWriter
    attr_reader :options

    def configure
        super
        return if(!@options)
        update_config(@options)
    end

    def update_config(options)
        @options = options
        STDOUT.puts "Starting real Poisitioning task with options: #{@options}"
        orocos_task.x = @options[:x] if @options[:x]
        orocos_task.y = @options[:y] if @options[:y]
        orocos_task.z = @options[:depth] if @options[:depth]
        orocos_task.heading = @options[:heading] if @options[:heading]
    end
    provides Base::AUVRelativeMotionControllerSrv, :as => "controller"
end

class AvalonControl::MotionControlTask 
    provides Base::AUVMotionControlledSystemSrv, :as => "auv_motion_controlled"
    #provides Base::ActuatorControllerSrv, :as => "actuator_controller"
    provides Base::JointsControllerSrv, :as => "actuator_controller"
    on :timeout do |event|
        emit :failed
    end
end

class AvalonControl::PositionControlTask
    provides Base::AUVRelativeMotionControlledSystemSrv, :as => "controlled_system"
    provides Base::AUVMotionControllerSrv, :as => "controller"
end

class AvalonControl::TrajectoryFollower
    attr_reader :trajectory

    def configure
        super
        return if(!@trajectory)
        orocos_task.trajectory = @trajectory
    end

    def update_target(target)
        points = []
        if target == "pipeline"
            points << Eigen::Vector3.new(-5.5,4,-5)
            #points << Eigen::Vector3.new(2,4,-5)
            points << Eigen::Vector3.new(0,0,-5)
            points << Eigen::Vector3.new(-5.5,-4,-5)
		elsif target == "over_pipeline"
			orocos_task.final_heading = 3.14
            points << Eigen::Vector3.new(-6.5,-1,-5)
            points << Eigen::Vector3.new(-3.5,5.3,-5)
            points << Eigen::Vector3.new(-2.0,5.9,-5)
            points << Eigen::Vector3.new(-0.5,5.5,-5)
		elsif target == "explore"
            points << Eigen::Vector3.new(-0.5,5.5,-5)
            points << Eigen::Vector3.new(-7,5.5,-5)
            points << Eigen::Vector3.new(0.0,0.0,-5)
            points << Eigen::Vector3.new(-6,-1,-5)
        
		else
            raise ArgumentError, "#{target} is unspported as a target for the trajectory mover"
        end
        trajectory = Types::Base::Trajectory.new
        spline = Types::Base::Geometry::Spline3.interpolate(points)
        trajectory.spline = spline
        orocos_task.trajectory = trajectory
        @trajectory = trajectory
    end
    provides Base::AUVRelativeMotionControllerSrv, :as => "controller"
end
