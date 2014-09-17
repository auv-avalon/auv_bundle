require 'models/blueprints/auv'
require 'models/blueprints/auv_control'
using_task_library 'auv_rel_pos_controller'
using_task_library 'uw_particle_localization'
using_task_library 'sonar_feature_estimator'
using_task_library 'sonar_feature_detector'
using_task_library 'sonar_wall_hough'
using_task_library 'sonar_feature_detector'


module Localization

    data_service_type 'HoughSrv' do
        output_port "position", "/base/samples/RigidBodyState"
        output_port "orientation_drift", "sonar_wall_hough/PositionQuality"
    end
    

    class ParticleDetector < Syskit::Composition
        add UwParticleLocalization::Task, :as => 'main'
        add Base::SonarScanProviderSrv, :as => 'sonar'
        add SonarFeatureEstimator::Task, :as => 'sonar_estimator'
        add ::Base::OrientationWithZSrv, :as => 'ori'
        #add Dev::Sensors::Hbridge, :as => 'hb'
        add Base::JointsStatusSrv, :as => 'hb'
        add_optional SonarFeatureDetector::Task, :as => 'sonar_detector'
        #add Base::JointsControllerSrv, :as => 'hb'
        add_optional ::Localization::HoughSrv, as: 'hough'

        if ::CONFIG_HACK == 'default'
            main_child.with_conf("default", "slam_testhalle")
        elsif ::CONFIG_HACK == 'simulation'
            main_child.with_conf("sim_nurc")
        elsif ::CONFIG_HACK == 'dagon'
            main_child.with_conf("dagon")
        end


        connect sonar_child => sonar_estimator_child
        connect ori_child => sonar_estimator_child.orientation_sample_port
        connect ori_child => main_child.orientation_samples_port
        connect sonar_estimator_child.features_out_port => main_child
        connect hb_child => main_child.thruster_samples_port
        connect hough_child => main_child.pose_update_port
        if ::CONFIG_HACK == 'dagon'
            add_optional ::Base::VelocitySrv, as: 'velocity'
            connect velocity_child.velocity_samples_port => main_child.speed_samples_port
        end
        connect main_child.pose_samples_port => sonar_detector_child.pose_samples_port
        connect main_child.grid_map_port => sonar_detector_child.grid_maps_port

        export main_child.pose_samples_port
        provides Base::PoseSrv, :as => 'pose'
        export main_child.dead_reckoning_samples_port, as: 'velocity_samples'
        provides Base::VelocitySrv, :as => 'velocity'
        #export sonar_detector_child.next_target_port
        #export sonar_detector_child.next_target_feature_port

        on :start do |ev|
            @reader = main_child.pose_samples_port.reader
            @sonar_in_use = true
        end

        poll do 
            if @reader 
                if sample = @reader.read
                    unless State.nil? 
                        unless State.position.nil?
                            State.position[:x] = sample.position.x
                            State.position[:y] = sample.position.y
                            State.position[:z] = sample.position.z
                        end
                    end
                end
            end

            wall_servoing = TaskContext.get 'wall_servoing'
            sonar_structure_servoing = TaskContext.get 'sonar_structure_servoing'

            if(wall_servoing.running? && !@sonar_in_use)
                @sonar_in_use = true
            end

            if(sonar_structure_servoing.running? && !@sonar_in_use)
                @sonar_in_use = true
            end

            if(@sonar_in_use && !wall_servoing.running? && !sonar_structure_servoing.running?)
                #reset sonar config
                @sonar_in_use = false
                orocos_t = nil
                if sonar_child.respond_to?(:orocos_task)
                    orocos_t = sonar_child.orocos_task
                else
                    #Simulation special case
                    orocos_t = sonar_child.find_child {|c| c.class == Simulation::Sonar }.orocos_task
                end

                orocos_t.apply_conf(['default','maritime_hall'],true)
            end
            
        end
#        @position = :position2 
#        
        #on :start do |ev|
        #        @reader = main_child.pose_samples_port.reader
#       #         emit @position if @position
        #end
        #poll do 
        #    if !log.nil? && log['particle_detector']
        #        # We should log!
        #        
        #        if @reader 
        #            if sample = @reader.read
        #                log['particle_detector']['data'] = sample.position
        #            end
        #        end
        #    end
        #end
#            if @reader
#                if sample = @reader.read
#                    col = nil
#                    row= nil
#                    if (sample.position[0] + basin_width/2.0) < (basin_width/3.0 * 1.0)
#                        col = 0
#                    elsif (sample.position[0] + basin_width/2.0) < (basin_width/3.0 * 2.0)
#                        col = 1
#                    else
#                        col = 2
#                    end
#                    if (sample.position[1] + basin_height/2.0) < (basin_height/3.0 * 1.0)
#                        row = 2
#                    elsif (sample.position[1] + basin_height/2.0) < (basin_height/3.0 * 2.0)
#                        row = 1
#                    else
#                        row = 0
#                    end
#                    new_position = my_events[col+(3*row)]
#                    if new_position != @position
#                        Robot.info "Got new position i'm on #{new_position}"
#                        emit new_position
#                        @position = new_position
#                    end
#                end
#            end
#        end
    end

    class DeadReckoning < Syskit::Composition
	add UwParticleLocalization::MotionModel, :as => 'main'
	add ::Base::OrientationWithZSrv, :as => 'ori'
	add Base::JointsStatusSrv, :as => 'hb'
        if ::CONFIG_HACK == 'default'
            main_child.with_conf("default")
        elsif ::CONFIG_HACK == 'simulation'
            main_child.with_conf("default")
        elsif ::CONFIG_HACK == 'dagon'
            main_child.with_conf("dagon")
        end
	
	connect ori_child => main_child
	connect hb_child => main_child
	
	export main_child.pose_samples_port
	provides Base::VelocitySrv, :as => 'pose'
    end
    
    class HoughDetector < Syskit::Composition
        add SonarWallHough::Task, as: 'main'
        add Base::SonarScanProviderSrv, as: 'sonar'
        add Base::OrientationSrv, as: 'ori'
        add_optional Base::DVLSrv, as: 'dvl'
        add_optional UwParticleLocalization::OrientationCorrection, :as => 'correction'

        connect sonar_child => main_child
        connect ori_child => main_child
        connect dvl_child => main_child.pose_samples_port
        connect main_child.position_quality_port => correction_child.orientation_offset_port

        export main_child.position_port, as: 'position'
        export main_child.position_quality_port, as: 'ori_drift'
        provides HoughSrv, as: 'hough'
    end
 
    class FixMapHack < Syskit::Composition

        add_optional SonarFeatureDetector::Task, :as => 'sonar_detector'

        on :start do |e|
            sonar_detector_child.fix_map()
            emit :success
            e
        end
    end    
    
#    class HoughParticleDetector < Syskit::Composition
#        add ParticleDetector.use(Localization::HoughDetector), :as => 'main'
#        #add Localization::HoughDetector.use(Localization::ParticleDetector), as: 'hough'
#        add Localization::HoughDetector, as: 'hough'
#        
#        export main_child.pose_samples_port
#        provides Base::PoseSrv, as: 'pose'
#
#    end

#    class Follower < ::Base::ControlLoop
#        add_main AvalonControl::RelFakeWriter, :as => "controller_local" 
##        add_main ParticleDetector, :as => "controller_local"
#        overload 'controller', AvalonControl::RelFakeWriter
#
#        
##        overload 'controlled_system', 
#
##        argument :timeout, :default => nil
##        argument :heading, :default => 0
##        argument :pos_x, :default => 0
##        argument :pos_y, :default => 0
##        argument :pos_z, :default => 0
#
##        attr_reader :start_time
##
##        on :start do |event|
##            Robot.info "Starting Position Mover"
##            @start_time = Time.now
##        end
#
##        script do
##            binding.pry
##            port = controlled_system_child.find_port("command_in")
##            position_writer = controlled_system_child.command_in_port.writer
##            sample = position_writer.sample.new
##            sample.x = pos_x
##            sample.y = pos_y
##            sample.z = pos_z
##            sample.heading = pos_heading
##            poll do
##                position_writer.write sample
##            end
##        end
#
##        poll do
##            if(self.timeout)
##                if(@start_time + self.timeout < Time.now)
##                    STDOUT.puts "Finished #{self} becaue time is over! #{@start_time} #{@start_time + self.timeout}"
##                    emit :success
##                end
##            end
##
##        end
#    end
#
##        argument :turn_dir, :default => nil
##        argument :heading, :default => nil
##        argument :depth, :default => nil
##        argument :speed_x, :default => nil
##        argument :timeout, :default => nil
#
##        event :check_candidate
##        event :follow_pipe
##        event :found_pipe
##        event :align_auv
##        event :lost_pipe
##        event :search_pipe
##        event :end_of_pipe
##        event :weak_signal
##        attr_reader :start_time
##
##        on :start do |event|
##            Robot.info "Starting Pipeline Follower with config: speed_x: #{speed_x}, heading: #{heading}, depth: #{depth}"
##            controller_child.update_config(:speed_x => speed_x, :heading => heading, :depth=> depth, :turn_dir => turn_dir)
##            @start_time = Time.now
##        end
end

