class PoseEstimation::UWPoseEstimator
    worstcase_processing_time 5.0
    def reset_heading(angle_in_rad)
         orocos_task.reset_heading(angle_in_rad)
    end
end
