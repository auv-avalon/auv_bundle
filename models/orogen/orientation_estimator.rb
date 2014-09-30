class OrientationEstimator::BaseEstimator
    worstcase_processing_time 5.0
end
module ::Base
    data_service_type 'OrientationToCorrectSrv' do
       input_port 'heading_offset', '/base/Angle'
    end
end
