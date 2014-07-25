require 'models/blueprints/sensors'
require 'models/blueprints/avalon'
require 'models/blueprints/localization.rb'
using_task_library 'auv_rel_pos_controller'
using_task_library 'offshore_pipeline_detector'
using_task_library 'line_scanner'
using_task_library 'image_preprocessing'
using_task_library 'pipeline_inspection'
using_task_library 'line_scanner'

module Pipeline

#    class LineScanner < Syskit::Composition 
#        add Base::ImageProviderSrv, :as => 'camera'
#        add ::LineScanner::Task, :as => 'scanner'
#        connect camera_child => scanner_child
#    end


    class LineScanner < Syskit::Composition

        add PipelineInspection::Inspection, :as => 'inspection'
        add Base::ImageProviderSrv, :as => 'camera'
        add OffshorePipelineDetector::Task, :as => 'offshore_pipeline_detector'
        add Localization::DeadReckoningSrv, :as => 'motion_model'
        add ::LineScanner::Task, :as => 'line_scan'


        connect camera_child => line_scan_child
        connect line_scan_child => inspection_child.laserPointCloud_port
        connect offshore_pipeline_detector_child => inspection_child
        connect motion_model_child => inspection_child

#        export inspection_child.inspectionStatus_port
#        export inspection_child.pipeMap_port
   end

        
    class Detector < Syskit::Composition 
        argument :heading, :default => nil
        argument :depth, :default => nil
        argument :speed_x, :default => nil
        argument :turn_dir, :default => nil

        event :check_candidate
        event :follow_pipe
        event :found_pipe
        event :align_auv
        event :lost_pipe
        event :search_pipe
        event :end_of_pipe
        event :weak_signal


        add Base::ImageProviderSrv, :as => 'camera'
#        add ImagePreprocessing::HSVSegmentationAndBlur, :as => 'blur'
        add_main OffshorePipelineDetector::Task, :as => 'offshorePipelineDetector'
        add Base::OrientationWithZSrv, :as => "orientation_with_z"
	add Pipeline::LineScanner, :as => "laser_scanner"
        orientation_with_z_child.connect_to offshorePipelineDetector_child.orientation_sample_port
        camera_child.frame_port.connect_to offshorePipelineDetector_child
  #      camera_child.frame_port.connect_to blur_child
 #       blur_child.oframe_port.connect_to offshorePipelineDetector_child
        export offshorePipelineDetector_child.find_port("position_command")
#        export offshorePipelineDetector_child.position_command_port
        provides Base::AUVRelativeMotionControllerSrv, :as => 'controller'
        export offshorePipelineDetector_child.pipeline_port
        attr_accessor :pipeline_heading
        attr_accessor :last_valid_heading

        script do
            orientation_reader = orientation_with_z_child.orientation_z_samples_port.reader
            poll do
                if o = orientation_reader.read
                    pipeline_heading = o.orientation.yaw
                end
            end
        end

#        refine_running_state do
#            poll_in_state :end_of_pipe do |task|
#                yaw = [:pose, :orientation].inject(State) do |value, field_name|
#                    if value.respond_to?(field_name)
#                        value.send(field_name)
#                    else break
#                    end
#                end
#                if !yaw.nil? && (yaw.yaw < 10* 180/Math::PI) && (yaw.yaw > 10 * -180/Math::PI)
#                    emit :end_of_pipe
#                else
#                    Robot.info "Heading incorrect, don't emit event"
#                end
#            end
#        end

        def update_config(options)
            offshorePipelineDetector_child.update_config(options)
        end

        on :weak_signal do |event|
            self.last_valid_heading = pipeline_heading
        end

        on :end_of_pipe do |event|
            Robot.info "got End of pipe Event"
            self.last_valid_heading = pipeline_heading
        end
    end

    class Follower < ::Base::ControlLoop

        #instead of adding it here:
        add_main Detector, :as => "controller_local"
        #implement something like this:
    #    pass_arguments_to_child my_child, :heading
    #    forward_from_child my_child, :check_candidate

        overload 'controller', Detector 
        
        #begin workaround TODO @sylvain
        #add AuvRelPosController::Task, :as => "workaround"
        #controller_child.position_command_port.connect_to workaround_child 
        #end workaround
        
        add_optional AvalonControl::PositionControlTask, :as => "workaround"
        connect controller_local_child.pipeline_port => workaround_child

        argument :turn_dir, :default => nil
        argument :heading, :default => nil
        argument :depth, :default => nil
        argument :speed_x, :default => nil
        argument :timeout, :default => nil

        event :check_candidate
        event :follow_pipe
        event :found_pipe
        event :align_auv
        event :lost_pipe
        event :search_pipe
        event :end_of_pipe
        event :weak_signal

        attr_reader :start_time

        on :start do |event|
            Robot.info "Starting Pipeline Follower with config: speed_x: #{speed_x}, heading: #{heading}, depth: #{depth}"
            controller_child.update_config(:speed_x => speed_x, :heading => heading, :depth=> depth, :turn_dir => turn_dir)
            @start_time = Time.now
        end

        poll do
                if(self.timeout)
                        if(@start_time + self.timeout < Time.now)
                                STDOUT.puts "Finished #{self} becaue time is over! #{@start_time} #{@start_time + self.timeout}"
                                emit :success
                        end
                end
        end
           
    end
    
end
