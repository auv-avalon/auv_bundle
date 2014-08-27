using_task_library "xsens_imu"
using_task_library "fog_kvh"
using_task_library "orientation_estimator"
#using_task_library "depth_reader"
using_task_library "uw_particle_localization"
using_task_library 'pose_estimation'


require "rock/models/blueprints/pose"
require "models/blueprints/auv.rb"

module PoseAuv
    class PoseEstimator < Syskit::Composition
        add_main PoseEstimation::UWPoseEstimator, :as => 'pose_estimator'
        add OrientationEstimator::IKF, :as => 'ori'
        add UwParticleLocalization::MotionModel, :as => 'model'
        add UwParticleLocalization::Task, :as => 'localization'
        add Base::ZProviderSrv, :as => 'depth'
        add_optional Base::VelocitySrv, as: 'velocity'

        if ::CONFIG_HACK == 'avalon'
            pose_estimator_child.with_conf("default", "avalon", "sauce")
        elsif ::CONFIG_HACK == 'simulation'
            pose_estimator_child.with_conf("default")
        elsif ::CONFIG_HACK == 'dagon'
            pose_estimator_child.with_conf("default", "dagon", "sauce")
        end

        connect ori_child => pose_estimator_child.orientation_samples_port
        connect model_child => pose_estimator_child.model_velocity_samples_port
        connect localization_child.pose_samples_port => pose_estimator_child.xy_position_samples_port
        connect depth_child => pose_estimator_child.depth_samples_port
        connect velocity_child => pose_estimator_child.dvl_velocity_samples_port

        export pose_estimator_child.pose_samples_port
        provides Base::PoseSrv, :as => 'pose'

        event :MISSING_TRANSFORMATION
    end

    class DagonOrientationEstimator < Syskit::Composition
        add OrientationEstimator::BaseEstimator, :as => 'estimator'
        add UwParticleLocalization::OrientationCorrection, :as => 'correction'

        add Base::OrientationSrv, :as => 'imu'
        add FogKvh::Dsp3000Task, :as => 'fog'

        #imu_child.connect_to correction_child.absolute_orientation_port
        estimator_child.connect_to correction_child.orientation_input_port

        imu_child.connect_to  estimator_child.imu_orientation_port
        fog_child.connect_to  estimator_child.fog_samples_port

        #export estimator_child.attitude_b_g_port, :as => 'orientation_samples'
        export correction_child.orientation_output_port, :as => 'orientation_samples'
        #export correction_child.orientation_offset_corrected_port, :as => 'orientation_samples'
        provides Base::OrientationSrv, :as => "orientation"
    end

#    class OrientationWithZ < Syskit::Composition 
#        add DepthReader::DepthAndOrientationFusion, :as => 'fusion'
#        
#        #add Srv::Orientation
#        add DagonOrientationEstimator, :as => 'orientation'
#        add Base::ZProviderSrv, :as => 'z_provider'
#
#        orientation_child.connect_to fusion_child.orientation_samples_port
#        z_provider_child.connect_to  fusion_child.depth_samples_port
#
#        export fusion_child.pose_samples_port
#        provides Base::OrientationWithZSrv, :as => "orientation_with_z"
#        provides Base::VelocitySrv, :as => "speed"
#    end
end
