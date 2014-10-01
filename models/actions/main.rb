require 'models/actions/core'

MISSION = "TESTBED"


#START_MOVE =   Hash.new({:finish_when_reached => true, :depth => -7, :delta_timeout => 5, :heading => Math::PI/2.0, :timeout_s => 30})
#TO_STRUCTURE = Hash.new({:timeout => 300, :depth => -2.5, :x => 3.0, :y=> 0})
#
#if MISSION == "SAUCE"
#    WALL_START_MOVE = {:finish_when_reached => true,  :heading => Math::PI/2.0, :depth => -5, :delta_timeout => 5, :x => -30, :y => 3 }
#elsif MISSION == "TESTBED"
#    WALL_START_MOVE = {:finish_when_reached => true,  :heading => Math::PI/2.0, :depth => -5, :delta_timeout => 5, :x => 50, :y => 0}
#elsif
#    raise "Invalid mission selection"
#end


class Main
    describe("align on wall to estimate the initial heading")
    state_machine "reset_heading_on_wall" do
        
        detector = state wall_detector_new_def#.with_conf('hold_wall_right') ##TODO URGEND
        init_wall = state wall_right_hold_pos_def
        #hold_wall = state wall_right_hold_pos_def
        init_wall.depends_on detector, :role => "foo"
        heading_estimator = state initial_orientation_estimator_def
        heading_estimator.depends_on init_wall #hold_wall, :role => "fasel"

        start(init_wall)
        transition(init_wall, detector.wall_servoing_event, heading_estimator)
        
        #forward heading_estimator.failed_event, failed_event
        #forward init_wall.failed_event, failed_event
        #forward hold_wall.failed_event, failed_event
        forward heading_estimator.success_event, success_event

    end

    describe("ping-pong-pipe-wall-back-to-pipe")
    state_machine "ping_pong_pipe_wall_back_to_pipe" do
        ping_pong = state pipe_ping_pong
        wall = state wall_right_def(:max_corners => 2)


        find_pipe_back = state find_pipe_with_localization
        find_pipe_back = state find_pipe_with_localization
        start(ping_pong)
        transition(ping_pong.success_event, wall)
        transition(wall.success_event,find_pipe_back)

	#timeout occured
        forward find_pipe_back.failed_event, failed_event
        #we found back the pipeline
        forward find_pipe_back.success_event, success_event ##todo maybe use align_auv insted?

     end

    describe("ping-pong-pipe-wall-back-to-pipe")
    state_machine "ping_pong_pipe_wall_back_to_pipe_with_window" do
        ping_pong = state pipe_ping_pong
        wall = state wall_right_def(:max_corners => 2)
        window = state to_window

        find_pipe_back = state find_pipe_with_localization
        start(ping_pong)
        transition(ping_pong.success_event, wall)
        transition(wall.success_event,window)
        transition(window.success_event,find_pipe_back)

	#timeout occured
        forward find_pipe_back.failed_event, failed_event
        #we found back the pipeline
        forward find_pipe_back.success_event, success_event ##todo maybe use align_auv insted?

     end

    describe("Do a pipeline ping-pong, pass two corners with wall servoing and goind back to pipe")
    state_machine "rocking" do
        s1 = state ping_pong_pipe_wall_back_to_pipe
        s2 = state ping_pong_pipe_wall_back_to_pipe
        start(s1)
        transition(s1.success_event,s2)
        transition(s2.success_event,s1)
    end

    describe("Do the minimal demo once")
    state_machine "minimal_demo_once" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -4, :delta_timeout => 5, :timeout => 15)

        s1 = state find_pipe_with_localization
        #pipeline1 = state intelligent_follow_pipe(:initial_heading => 0, :precision => 10, :turn_dir => 1)
        pipeline1 = state pipeline_def(:depth => -5.5, :heading => 0, :speed_x => 0.5, :turn_dir=> 1, :timeout => 180)
        align_to_wall = state simple_move_def(:finish_when_reached => true, :heading => 3.14, :depth => -5, :delta_timeout => 5, :timeout => 15)
        rescue_move = state target_move_def(:finish_when_reached => true, :heading => Math::PI, :depth => -5, :delta_timeout => 5, :x => 0.5, :y => 5.5)
        #Doing wall-servoing
        wall1 = state wall_right_def(:max_corners => 1)
        wall2 = state wall_right_def(:timeout => 20)

        surface = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => 1, :speed_x => 0.1, :delta_timeout => 5, :timeout => 30)

        start(init)
        transition(init.success_event, s1)
        transition(s1.success_event, pipeline1)
        transition(s1.failed_event, rescue_move)
        transition(pipeline1.end_of_pipe_event, align_to_wall)
        transition(pipeline1.success_event, align_to_wall)
        transition(pipeline1.lost_pipe_event, rescue_move)
        transition(rescue_move.success_event, wall1)
        transition(align_to_wall.success_event, wall1)

        transition(wall1.success_event, wall2)
        transition(wall2.success_event, surface)
        forward surface.success_event, success_event
    end


    describe("Do the minimal demo for the halleneroeffnung, means pipeline, then do wall-following and back to pipe-origin")
    state_machine "minimal_demo" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -7, :delta_timeout => 5, :timeout => 15, :speed_x => 0)
        s1 = state find_pipe_with_localization(:check_pipe_angle => true)
#        detector = state pipeline_detector_def
#        detector.depends_on s1

        #Follow pipeline to right end
        pipeline1 = state pipeline_def(:depth=> -7.1, :heading => 0, :speed_x => 0.5, :turn_dir=> 1, :timeout => 120)
        #pipeline1 = state intelligent_follow_pipe(:precision => 5, :initial_heading => 0, :turn_dir=> 1)
        #pipeline1 = state intelligent_follow_pipe(:initial_heading => 0, :precision => 10, :turn_dir => 1)
#        align_to_wall = state simple_move_def(:finish_when_reached => true, :heading => 3.14, :depth => -6, :delta_timeout => 5, :timeout => 15)
        rescue_move = state target_move_def(:finish_when_reached => true, :heading => Math::PI, :depth => -6, :delta_timeout => 20, :x => 0.5, :y => 5.5, :speed_x => 0)
        #Doing wall-servoing
        wall1 = state wall_right_def(:max_corners => 1)
        wall2 = state wall_right_def(:timeout => 30)
        blind1 = state simple_move_def(:heading => 0.0, :depth => -6.0, :timeout => 5)
        blind2 = state simple_move_def(:heading => 0.0, :depth => -6.0, :timeout => 5, :speed_x => 0.15)

        start(init)
        transition(init.success_event, s1)
        transition(s1.success_event, pipeline1)
        transition(s1.failed_event, rescue_move)
        #transition(pipeline1.success_event, align_to_wall)
        transition(pipeline1.end_of_pipe_event, rescue_move)
        transition(pipeline1.success_event, rescue_move)
        transition(pipeline1.failed_event, rescue_move)
        #transition(pipeline1.lost_pipe_event, rescue_move)
        transition(rescue_move.success_event, wall1)
#        transition(align_to_wall.success_event, wall1)

        transition(wall1.success_event, wall2)
        transition(wall2.success_event, blind1)
        transition(blind1.success_event, blind2)
        transition(blind2.success_event, s1)

        #prepare_jumpin("wall" => wall1, "pipeline"=> pipeline1)
    end

    describe("Do the minimal demo for the halleneroeffnung, menas pipeline, then do wall-following and back to pipe-origin")
    state_machine "minimal_demo_blind" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -4, :delta_timeout => 5, :timeout => 15)
        #s1 = state find_pipe_with_localization_

        #Follow pipeline to right end

	pipeline1 = state trajectory_move_def(:target => 'over_pipeline', :timeout => 125)
        #Doing wall-servoing
        wall1 = state wall_right_def(:max_corners => 1)
        wall2 = state wall_right_def(:timeout => 23)

        start(init)
        transition(init.success_event, pipeline1)
#        transition(s1.success_event, pipeline1)
        #transition(pipeline1.success_event, align_to_wall)
        transition(pipeline1.reached_end_event, wall1)
        #transition(align_to_wall.success_event, wall1)

        transition(wall1.success_event, wall2)
        transition(wall2.success_event, pipeline1)

    end


    #TODO This could be extended by adding additional mocups
    describe("do a full Demo, with visiting the window after wall-servoing")
    state_machine "full_demo" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -6, :delta_timeout => 5, :timeout => 15)
        s1 = state find_pipe_with_localization

        #Follow pipeline to right end
        pipeline1 = state pipeline_def(:depth=> -5.5, :heading => 0, :speed_x => 0.5, :turn_dir=> 1, :timeout => 180)
	align_to_wall = state simple_move_def(:finish_when_reached => true, :heading => 3.14, :depth => -6, :delta_timeout => 5, :timeout => 15)
        #Doing wall-servoing
        wall1 = state wall_right_def(:max_corners => 1)
        wall2 = state wall_right_def(:timeout => 20)

		s2 = state find_pipe_with_localization

        #Follow pipeline to right end
        pipeline1_2 = state pipeline_def(:depth=> -5.5, :heading => 0, :speed_x => 0.5, :turn_dir=> 1, :timeout => 180)

        throught_becken = state trajectory_move_def(:target => "explore")


        start(init)
        transition(init.success_event, s1)
        transition(s1.success_event, pipeline1)
        #transition(pipeline1.success_event, align_to_wall)
        transition(pipeline1.end_of_pipe_event, align_to_wall)
        transition(pipeline1.success_event, align_to_wall)
        transition(align_to_wall.success_event, wall1)
        transition(wall1.success_event, wall2)
        transition(wall2.success_event, s2)
        transition(s2.success_event, pipeline1_2)
        transition(pipeline1_2.success_event, throught_becken)
        transition(pipeline1_2.end_of_pipe_event, throught_becken)
		transition(throught_becken.success_event,s1)
    end

    describe("foo")
    state_machine "trajectory_demo" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -7, :delta_timeout => 5, :timeout => 15, :speed_x => 0)
        trajectory = state trajectory_move_def  #(:trajectory => ['default','hall_cool'])
        pipe = state find_pipe_with_localization
        pipeline1 = state pipeline_def(:depth=> -7, :heading => 0, :speed_x => 0.5, :turn_dir=> 1, :timeout => 120)
        rescue_move = state target_move_def(:finish_when_reached => true, :heading => Math::PI, :depth => -6, :delta_timeout => 20, :x => 0.5, :y => 5.5, :speed_x => 0)
        wall1 = state wall_right_def(:max_corners => 1)
        wall2 = state wall_right_def(:timeout => 23)
        start(init)
        transition(init.success_event,trajectory)
        transition(trajectory.reached_end_event,pipe)
        transition(pipe.success_event,pipeline1)
        transition(pipeline1.end_of_pipe_event,rescue_move)
        transition(pipeline1.success_event,rescue_move)
        transition(pipeline1.lost_pipe_event,rescue_move)
        transition(rescue_move.success_event,wall1)
        transition(wall1.success_event,wall2)
        transition(wall2.success_event,trajectory)
    end

    describe("Do the minimal demo for the halleneroeffnung, means pipeline, then do wall-following and back to pipe-origin")
    state_machine "advanced_demo" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -7, :delta_timeout => 5, :timeout => 15, :speed_x => 0)
        s1 = state find_pipe_with_localization
#        detector = state pipeline_detector_def
#        detector.depends_on s1

        #Follow pipeline to right end
        pipeline1 = state pipeline_def(:depth=> -7, :heading => 0, :speed_x => 0.5, :turn_dir=> 1, :timeout => 120)
        #pipeline1 = state intelligent_follow_pipe(:precision => 5, :initial_heading => 0, :turn_dir=> 1)
        #pipeline1 = state intelligent_follow_pipe(:initial_heading => 0, :precision => 10, :turn_dir => 1)
        align_to_wall = state simple_move_def(:finish_when_reached => true, :heading => Math::PI/2, :depth => -7, :delta_timeout => 5, :timeout => 15)
        rescue_move = state target_move_def(:finish_when_reached => true, :heading => 0, :depth => -7, :delta_timeout => 5, :x => 0.5, :y => 5.5, :speed_x => 0)
        start_window_move = state target_move_def(:finish_when_reached => true, :heading => -Math::PI/5, :depth => -7, :delta_timeout => 5, :x => 9.5, :y => 0, :speed_x => 1)
        #Doing wall-servoing
        wall1 = state wall_right_def(:max_corners => 3)
        #wall2 = state wall_right_def(:timeout => 30)
        blind1 = state simple_move_def(:heading => Math::PI/3, :depth => -7.0, :timeout => 5)
        blind2 = state simple_move_def(:heading => Math::PI/3, :depth => -7.0, :timeout => 15, :speed_x => 0.15)

        start(init)
        transition(init.success_event, s1)
        transition(s1.success_event, pipeline1)
        transition(s1.failed_event, rescue_move)
        #transition(pipeline1.success_event, align_to_wall)
        transition(pipeline1.end_of_pipe_event, start_window_move)
        transition(pipeline1.success_event, start_window_move)
        transition(pipeline1.failed_event, rescue_move)
        #transition(pipeline1.lost_pipe_event, rescue_move)
        transition(start_window_move.success_event, align_to_wall)
        transition(align_to_wall.success_event, wall1)
        transition(rescue_move.success_event, start_window_move)

        transition(wall1.success_event, blind1)
        #transition(wall2.success_event, blind1)
        transition(blind1.success_event, blind2)
        transition(blind2.success_event, s1)
    end

    describe("Do the minimal demo for the halleneroeffnung, means pipeline, then do wall-following and back to pipe-origin")
    state_machine "advanced_demo_once" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -7, :delta_timeout => 5, :timeout => 15, :speed_x => 0)
        s1 = state find_pipe_with_localization
#        detector = state pipeline_detector_def
#        detector.depends_on s1

        #Follow pipeline to right end
        pipeline1 = state pipeline_def(:depth=> -7.1, :heading => 0, :speed_x => 0.5, :turn_dir=> 1, :timeout => 120)
        #pipeline1 = state intelligent_follow_pipe(:precision => 5, :initial_heading => 0, :turn_dir=> 1)
        #pipeline1 = state intelligent_follow_pipe(:initial_heading => 0, :precision => 10, :turn_dir => 1)
        align_to_wall = state simple_move_def(:finish_when_reached => true, :heading => 3.14, :depth => -6, :delta_timeout => 5, :timeout => 15)
        rescue_move = state target_move_def(:finish_when_reached => true, :heading => Math::PI, :depth => -6, :delta_timeout => 5, :x => 0.5, :y => 5.5, :speed_x => 0)
        #Doing wall-servoing
        wall1 = state wall_right_def(:max_corners => 1)
        wall2 = state wall_right_def(:timeout => 30)
        blind1 = state simple_move_def(:heading => 0.0, :depth => -6.0, :timeout => 5)
        blind2 = state simple_move_def(:heading => 0.0, :depth => -6.0, :timeout => 5, :speed_x => 0.15)

        start(init)
        transition(init.success_event, s1)
        transition(s1.success_event, pipeline1)
        transition(s1.failed_event, rescue_move)
        #transition(pipeline1.success_event, align_to_wall)
        transition(pipeline1.end_of_pipe_event, align_to_wall)
        transition(pipeline1.success_event, align_to_wall)
        transition(pipeline1.failed_event, rescue_move)
        #transition(pipeline1.lost_pipe_event, rescue_move)
        transition(rescue_move.success_event, wall1)
        transition(align_to_wall.success_event, wall1)

        transition(wall1.success_event, wall2)
        transition(wall2.success_event, blind1)
        transition(blind1.success_event, blind2)
        forward blind2.success_event, success_event
    end

    describe("search for structure and align on it")
    state_machine "search_structure" do
        to_structure = state target_move_new_def(:timeout => 300, :depth => -7, :x => -45.0, :y=> 25, :heading => Math::PI/2)
        searching_structure = state structure_align_detector_def
        aligner = state structure_alignment_def

        to_structure.depends_on searching_structure, :role => "search_structure"

        start(to_structure)
        transition(to_structure, searching_structure.aligning_event, aligner)
        
        forward aligner.aligned_event, success_event
        forward to_structure, searching_structure.aligned_event, success_event
    end
    
    describe("find_blackbox")
    state_machine "find_blackbox" do
      
      #create multiple waypoints to explore the environment
      explore = state explore_map
      surface = state target_move_new_def(:finish_when_reached => true, :depth => 0.0, :delta_timeout => 5)
      map_fix = state fix_map_hack
      map_reset = state fix_map_hack
      search = state search_blackbox
      
      buoy_detector = state buoy_detector_bottom_def
      localization = state localization_def
      sonar_target_move = state sonar_target_move_def, :role => "sonar_detector"
      
      search.depends_on localization
      search.depends_on buoy_detector
      sonar_target_move.depends_on buoy_detector      
      explore.depends_on localization
      map_fix.depends_on localization
      map_reset.depends_on localization
      sonar_target_move.depends_on localization      
      
      start explore
      
      transition explore.success_event, map_fix
      transition map_fix.success_event, sonar_target_move 
      transition sonar_target_move.reached_target_event, search 
      transition sonar_target_move.servoing_finished_event, map_reset #we finished all targets, but found nothing :-(
      transition sonar_target_move.not_enough_targets_event, map_reset #exploration finished, but nothing found :-(
      transition search.success_event, sonar_target_move  #Search finished, but found nothig -> continue with next target      
      transition map_reset.success_event, explore
      
      transition search, buoy_detector.buoy_detected_event, surface 
            
      forward surface.success_event, success_event
      
    end    
    

    #describe("Passing validation-gate with localization")
    #state_machine "gate_with_localization" do 
#
#    end

    
    describe("Passing validation-gate without localization")
    state_machine "gate_without_localization" do
        dive = state simple_move_new_def(:finish_when_reached => true, :depth => -7, :delta_timeout => 5, :heading => Math::PI/2.0, :timeout => 60)
        s_search_structure = state search_structure
        #TODO Avalon does not seems to pass the gate
        gate_passing = state blind_forward_and_back(:time => 20, :speed => 1.0, :heading => -Math::PI, :depth => -4)

        start(dive)
        transition(dive.success_event, s_search_structure)
        transition(s_search_structure.success_event, gate_passing)
        forward gate_passing.success_event, success_event
        #transition(gate_passing.success_event, to_wall)
        #transition(to_wall.success_event, wall)
        #forward wall.success_event, success_event
    end

    describe("Moving to wall and start wall_servoing")
    state_machine "wall_with_localization" do
        #TODO not working here, input missing on controlchain
        to_wall = state target_move_new_def(:finish_when_reached => true,  :heading => Math::PI/2, :depth => -1.5, :delta_timeout => 2, :x => -3, :y => 26.5)#, :delta_xy => 3 ) 
        wall  = state buoy_wall

        start(to_wall)
        transition(to_wall.success_event, wall)
        forward wall.success_event, success_event
    end


    describe("Structure_inspection_dummy")
    state_machine "structure_inspection" do
        back_off = state simple_move_new_def(:finish_when_reached => true, :depth => -9, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -15, :timeout => 20) 
        move = state target_move_new_def(:x => -22.5, :y => 25, :delta_timeout => 5, :timeout => 120, :depth => -2)
        inspection = state structure_inspection_def(:timeout => 60)

        find = state structure_detector_def

        move.depends_on find

        #inspection.monitor(
        #    'round',
        #    inspection.find_port('pose'),
        #    :rounds => 1).
        #    trigger_on do |pose|
        #        pos = pose.yaw
        #        pos > 1.9 * Math::PI
        #    end.
        #    emit inspection.success_event

        start back_off
        transition back_off.success_event, move
        transition move, find.servoing_event, inspection
        forward inspection.success_event, success_event
    end
    
    describe("Blind Localizaton based qualifyiing")
    state_machine "blind_quali" do
        init = state simple_move_def(:finish_when_reached => true, :heading => Math::PI/2, :depth => -2, :x_speed => 1, :timeout => 10)
        to = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -22, :y => 25,  :timeout => 150) 
        align = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => 0, :x => -22, :y => 25,  :timeout => 30) 
        gate = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 0.22, :x => -5, :y => 26.5,  :timeout => 60) #
        #wall = state wall_right_new_def(:timeout => 150)

        start init 
        transition init.success_event, to
        transition to.success_event, align 
        transition align.success_event, gate 
        #transition gate.success_event, wall
        forward gate.success_event, success_event
    end
    describe("quali")
    state_machine "target_wall_buoy_wall" do

        to = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 0.22, :x => -5, :y => 26.5,  :timeout => 60)
        align = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 1.57, :x => -5, :y => 26.5,  :timeout => 60)
        search = state wall_and_buoy
        #buoy = state wall_buoy_survey_def 
        buoy = state simple_move_def(:x_speed => 0, :y_speed => 0, :timeout => 5, :heading => Math::PI/2, :depth => -1.5)
        back = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => -Math::PI * 0.75, :x => -22,     :y => 25,  :timeout => 150) 
        search_continue = state wall_continue #wall_right_def
        search_continue2 = state wall_right_new_def(:timeout => 20)

        start to 
        transition to.success_event, align
        transition align.success_event, search
        transition(search.success_event, buoy)
        transition(buoy.success_event, search_continue)
        transition search_continue.success_event, search_continue2
        transition search_continue2.success_event, back

        forward back.success_event, success_event
    end

    describe("We win the SAUC-E")
    state_machine "win" do

        #gate = state gate_without_localization
        #gate = state gate_with_localization
        gate = state blind_quali

        structure = state inspect_structure

        wall = state target_wall_buoy_wall

        #blackbox = state find_blackbox

        start gate
        transition gate.success_event, wall
        #transition structure.success_event, wall
        transition wall.success_event, structure 

        forward structure.success_event, success_event
    end

    describe("We win the SAUC-E")
    state_machine "WandBoje" do

        wall = state wall_with_localization

        start wall 

        forward wall.success_event, success_event
    end

    describe("We win the SAUC-E")
    state_machine "WandBojeJudge" do
        init = state simple_move_def(:finish_when_reached => true, :heading => 0, :depth => -2, :timeout => 8)

        wall = state wall_with_localization

        start init

        transition init.success_event, wall

        forward wall.success_event, success_event
    end

    describe("We win the SAUC-E")
    state_machine "QualiBoje" do

        gate = state blind_quali 

        wall = state wall_with_localization

        move = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 40, :heading => -Math::PI*0.7, :x => -22, :y => 25,  :timeout => 3)

        start gate
        transition gate.success_event, wall
        transition wall.success_event, move

        forward move.success_event, success_event
    end

    describe("only_wall")
    state_machine "only_wall" do
        wall_one = state wall_right_new_def(:timeout => 240, :max_corners => 1)
        wall_two = state wall_right_new_def(:timeout => 20)
        start wall_one 
        transition wall_one.success_event, wall_two
        transition wall_one.failed_event, wall_two
        forward wall_two.success_event, success_event
                            end

#    describe("test")
#    state_machine "test" do
#
#        move = state simple_move_new_def(:timeout => 3)
#        move = state simple_move_new_def(:timeout => 3)
#        move = state simple_move_new_def(:timeout => 3)
#        move = state simple_move_new_def(:timeout => 3)
#        move = state simple_move_new_def(:timeout => 3)
#        move = state simple_move_new_def(:timeout => 3)
#        move = state simple_move_new_def(:timeout => 3)
#        move = state simple_move_new_def(:timeout => 3)
#
#        start move
#        transition move.success_event, move1 
#        transition move1.success_event, move2 
#        transition move2.success_event, move3 
#        transition move3.success_event, move4 
#        transition move4.success_event, move5 
#        transition move5.success_event, move6 
#        transition move6.success_event, move7 
#
#        forward move7.success_event, success_event
#    end

    describe("quali")
    state_machine "wall" do

        wall = state wall_right_new_def(:timeout => 300, :corners => 1)

        start wall

        forward wall.success_event, success_event
    end

    #TODO in Core weil gibt es schon
#    describe("quali")
#    state_machine "wall_buoy" do
#
#        wall = state buoy_wall
#
#        start wall
#
#        forward wall.success_event, success_event
#    end


    describe("quali")
    state_machine "wall_buoy_wall" do

        search = state wall_and_buoy
        buoy = state wall_buoy_survey_def 
        search_continue = state wall_continue #wall_right_def

        start search

        transition(search.success_event, buoy)
        transition(buoy.success_event, search_continue)

        forward search_continue.success_event, success_event
    end

    describe("quali")
    state_machine "wall_buoy" do

        search = state wall_and_buoy
        buoy = state wall_buoy_survey_def 

        start search

        transition(search.success_event, buoy)

        forward buoy.success_event, success_event
    end

    describe("quali mit targetmove")
    state_machine "target_wall" do

        to = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 0.33, :x => -5, :y => 26.5,  :timeout => 60)
        wall = state wall_right_new_def(:timeout => 300, :corners => 1)
        back = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0 + Math::PI, :x => -22,     :y => 25,  :timeout => 150) 

        start to
        transition to.success_event, wall
        transition wall.success_event, back

        forward back.success_event, success_event
    end

    describe("buoy wall")
    state_machine "target_wall_buoy" do
        to = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 0.22, :x => -5, :y => 26.5,  :timeout => 60)
        search = state wall_and_buoy
        #buoy = state wall_buoy_survey_def 
        buoy = state simple_move_def(:x_speed => 0, :y_speed => 0, :timeout => 5, :heading => Math::PI/2, :depth => -1.5)
        back = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -22,     :y => 25,  :timeout => 150) 
        start to 
        transition to.success_event, search
        transition(search.success_event, buoy)
        transition buoy.success_event, back
        forward back.success_event, success_event
    end

    describe("quali")
    state_machine "target_wall_buoy_wall" do

        to = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 0.22, :x => -5, :y => 26.5,  :timeout => 60)
        align = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 1.57, :x => -5, :y => 26.5,  :timeout => 60)
        search = state wall_and_buoy
        #buoy = state wall_buoy_survey_def 
        buoy = state simple_move_def(:x_speed => 0, :y_speed => 0, :timeout => 5, :heading => Math::PI/2, :depth => -1.5)
        back = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => -Math::PI * 0.75, :x => -22,     :y => 25,  :timeout => 150) 
        search_continue = state wall_continue #wall_right_def
        search_continue2 = state wall_right_new_def(:timeout => 20)
        asv = state modem_def

        search_continue.depends_on asv

        start to 
        transition to.success_event, align
        transition align.success_event, search
        transition(search.success_event, buoy)
        transition(buoy.success_event, search_continue)
        transition search_continue.success_event, search_continue2
        transition search_continue2.success_event, back

        forward back.success_event, success_event
    end
    

    describe("quali")
    state_machine "wall_buoy_asv_wall" do

        search = state wall_and_buoy
        buoy = state wall_buoy_survey_def 
        shout = state shout_asv_def
        search_continue = state wall_continue #all_right_def

        start search

        transition(search.success_event, buoy)
        transition(buoy.success_event, shout)
        transition(shout.success_event, search_continue)

        forward search.success_event, success_event
    end

    #describe("quali")
    #state_machine "target_wall_buoy_wall" do
#
#        to = state target_move_new_def(:finish_when_reached => true, :depth => -1.5, :delta_timeout => 5, :heading => 0.22, :x => -5, :y => 26.5,  :timeout => 60)
#        search = state wall_and_buoy
#        buoy = state wall_buoy_survey_def 
#        back = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -22,     :y => 25,  :timeout => 150) 
#        shout = state shout_asv_def
#        search_continue = state wall_continue #wall_right_def
#
#        start to 
#        transition to.success_event, search
#        transition(search.success_event, buoy)
#        transition(buoy.success_event, shout)
#        transition(shout.success_event, search_continue)
#        transition search_continue.success_event, back
#
#        forward back.success_event, success_event
#    end

# WALL TEIL FERTIG
# # Structure Teil
#
    
    describe("quali")
    state_machine "structure" do

        structure = state structure_inspection_def

        start structure

        forward structure.success_event, success_event
    end

    describe("quali")
    state_machine "structure" do

        to = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -22,     :y => 25,  :timeout => 150) 
        structure = state structure_inspection_def
        back = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -22,     :y => 25,  :timeout => 5) 

        start to
        transition to.success_event, structure
        transition structure.success_event, back

        forward back.success_event, success_event
    end


    ### Structure Teil fertig
    ### Blackbox Teil
    #


    describe("quali")
    state_machine "box" do

        to = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -15,     :y => 35,  :timeout => 150) 
        back = state simple_move_new_def(:finish_when_reached => true, :depth => -2, :delta_x => -22,     :delta_y => 25,  :timeout => 5) 
        box_found = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -22,     :y => 25,  :timeout => 5) 

        start to
        transition to.success_event, box_found
        transition box_found.success_event, back

        forward back.success_event, success_event
    end

    describe("quali")
    state_machine "box_search" do

        to = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => Math::PI/2.0, :x => -15,     :y => 35,  :timeout => 150) 
        back = state simple_move_new_def(:finish_when_reached => true, :depth => -2, :delta_x => -22,     :delta_y => 25,  :timeout => 5) 
        box_search = state buoy_detector_bottom_def 

        start to
        transition to.success_event, box_search
        transition box_search.success_event, back

        forward back.success_event, success_event
    end

    describe("quali")
    state_machine "leak" do

        to = state simple_move_new_def(:finish_when_reached => true, :depth => -2, :heading => Math::PI*0.75, :x_speed => 1,     :y_speed => 0,  :timeout => 30) 
        search_buoy1 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -11, :y => 12,  :delta_timeout => 5, :timeout => 60, :heading => -Math::PI/2) 
        search_buoy2 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -17, :y => 13,  :delta_timeout => 5, :timeout => 60, :heading => Math::PI) 
        search_buoy3 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -18, :y => 12,  :delta_timeout => 5, :timeout => 60, :heading => Math::PI*0.75) 
        search_buoy4 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -19, :y => 16,  :delta_timeout => 5, :timeout => 60, :heading => Math::PI/2) 
        search_buoy5 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -16, :y => 17,  :delta_timeout => 5, :timeout => 60, :heading => 0) 
        search_buoy6 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -22, :y => 16,  :delta_timeout => 5, :timeout => 60, :heading => Math::PI) 
        search_buoy7 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -22, :y => 19,  :delta_timeout => 5, :timeout => 60, :heading => Math::PI/2) 
        search_buoy8 = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -21, :y => 22,  :delta_timeout => 5, :timeout => 60, :heading => Math::PI/2) 
        to_structure = state target_move_new_def(:finish_when_reached => true, :depth => -2, :x => -22, :y => 25,  :delta_timeout => 5, :timeout => 60, :heading => Math::PI/2) 
        back_to_structure = state target_move_new_def(:finish_when_reached => true, :depth => -4, :x => -22, :y => 25,  :delta_timeout => 5, :timeout => 60, :heading => -Math::PI*0.75) 


        structure = state inspect_structure
        intelli_structure = state structure_inspection_def

        double_buoy = state double_buoy_def

        to.depends_on double_buoy

        box_search = state buoy_detector_bottom_def 

        start to
        transition to.success_event, search_buoy1
            transition search_buoy1.success_event, search_buoy2
        transition search_buoy2.success_event, search_buoy3
        transition search_buoy3.success_event, search_buoy4
        transition search_buoy4.success_event, search_buoy5
        transition search_buoy5.success_event, search_buoy6
        transition search_buoy6.success_event, search_buoy7
        transition search_buoy7.success_event, search_buoy8
        transition search_buoy8.success_event, to_structure 
        transition to_structure.success_event, structure
        transition structure.success_event, back_to_structure
        transition back_to_structure.success_event, intelli_structure

        forward intelli_structure.success_event, success_event
        forward intelli_structure.no_structure_event, success_event
        forward intelli_structure.failed_event, success_event
    end

    WAYPOINTS = [{:x => 1, :y => 2}, {:x => 3, :y => 4}, {:x => 5, :y => 6}, {:x => 7, :y => 8}, {:x => 9, :y => 10}]
    waypoints_gps = [9.86307609309587,44.09549659601309,0,9.858986854993077,44.09438744752904,0,9.859562696265362,44.09326653728764,0,9.862565387611168,44.09410998907941,0,9.863056185133631,44.09545574769171,0]

    describe("Long range navigation")
    state_machine("longrange") do
    to_start = state target_move_new_def(:x => WAYPOINTS[0][:x], :y => WAYPOINTS[0][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI, :timeout => 480 )
    surface_start = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp1 = state target_move_new_def(:x => WAYPOINTS[1][:x], :y => WAYPOINTS[1][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI, :timeout => 900)
    surface_wp1 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp2 = state target_move_new_def(:x => WAYPOINTS[2][:x], :y => WAYPOINTS[2][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => -Math::PI/2, :timeout => 480)
    surface_wp2 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp3 = state target_move_new_def(:x => WAYPOINTS[3][:x], :y => WAYPOINTS[3][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => 0, :timeout => 900)
    surface_wp3 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp4 = state target_move_new_def(:x => WAYPOINTS[4][:x], :y => WAYPOINTS[4][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI/4, :timeout => 480)
    surface_wp4 = state simple_move_new_def(:depth => 0.5, :timeout => 15)

    start to_start
    transition to_start.success_event, surface_start
    transition surface_start.success_event, to_wp1
    transition to_wp1.success_event, surface_wp1
    transition surface_wp1.success_event, to_wp2
    transition to_wp2.success_event, surface_wp2
    transition surface_wp2.success_event, to_wp3
    transition to_wp3.success_event, surface_wp3
    transition surface_wp3.success_event, to_wp4
    transition to_wp4.success_event, surface_wp4
    forward surface_wp4.success_event, success_event
    end

    describe("Long range navigation")
    state_machine("longrangei_failsafe") do
    to_start = state target_move_new_def(:x => WAYPOINTS[0][:x], :y => WAYPOINTS[0][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI, :timeout => 480 )
    surface_start = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp1 = state target_move_new_def(:x => WAYPOINTS[1][:x], :y => WAYPOINTS[1][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI, :timeout => 900)
    surface_wp1 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp2 = state target_move_new_def(:x => WAYPOINTS[2][:x], :y => WAYPOINTS[2][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => -Math::PI/2, :timeout => 480)
    surface_wp2 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp3 = state target_move_new_def(:x => WAYPOINTS[3][:x], :y => WAYPOINTS[3][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => 0, :timeout => 900)
    surface_wp3 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp4 = state target_move_new_def(:x => WAYPOINTS[4][:x], :y => WAYPOINTS[4][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI/4, :timeout => 480)
    surface_wp4 = state simple_move_new_def(:depth => 0.5, :timeout => 15)

    start to_start
    transition to_start.success_event, surface_start
    transition surface_start.success_event, to_wp1
    transition to_wp1.success_event, surface_wp1
    transition surface_wp1.success_event, to_wp2
    transition to_wp2.success_event, surface_wp2
    transition surface_wp2.success_event, to_wp3
    transition to_wp3.success_event, surface_wp3
    transition surface_wp3.success_event, to_wp4
    transition to_wp4.success_event, surface_wp4
    forward surface_wp4.success_event, success_event
    end

    WAYPOINTS_test = [{:x => -170, :y => 25}, {:x => -170, :y => 10}, {:x => -200, :y => 10}, {:x => -200, :y => 40}, {:x => -170, :y => 40}]

    describe("Long range navigation")
    state_machine("longrangei_test") do
    to_start = state target_move_new_def(:x => WAYPOINTS_test[0][:x], :y => WAYPOINTS_test[0][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI, :timeout => 480 )
    surface_start = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp1 = state target_move_new_def(:x => WAYPOINTS_test[1][:x], :y => WAYPOINTS_test[1][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI, :timeout => 900)
    surface_wp1 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp2 = state target_move_new_def(:x => WAYPOINTS_test[2][:x], :y => WAYPOINTS_test[2][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => -Math::PI/2, :timeout => 480)
    surface_wp2 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp3 = state target_move_new_def(:x => WAYPOINTS_test[3][:x], :y => WAYPOINTS_test[3][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => 0, :timeout => 900)
    surface_wp3 = state simple_move_new_def(:depth => 0.5, :timeout => 15)
    to_wp4 = state target_move_new_def(:x => WAYPOINTS_test[4][:x], :y => WAYPOINTS_test[4][:y], :depth => 2.5, :delta_x => 4, :delta_y => 4, :delta_timeout => 5, :finished_when_reached => true, :heading => Math::PI/4, :timeout => 480)
    surface_wp4 = state simple_move_new_def(:depth => 0.5, :timeout => 15)

    start to_start
    transition to_start.success_event, surface_start
    transition surface_start.success_event, to_wp1
    transition to_wp1.success_event, surface_wp1
    transition surface_wp1.success_event, to_wp2
    transition to_wp2.success_event, surface_wp2
    transition surface_wp2.success_event, to_wp3
    transition to_wp3.success_event, surface_wp3
    transition surface_wp3.success_event, to_wp4
    transition to_wp4.success_event, surface_wp4
    forward surface_wp4.success_event, success_event
    end


    describe("euRathlon Anomaly")
    state_machine "anomaly" do

        # get a working localization
        out = state simple_move_new_def(:depth => -1.5, :heading => -Math::PI, :x_speed => 1, :y_speed => 0,  :timeout => 20)
        # drive to wall and survey
        to_wall = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 5, :x => -22, :y => 44, :depth => 2, :heading => Math::PI, :timeout => 90)
        align = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 5, :x => -22, :y => 44, :depth => 2, :heading => 0, :timeout => 90)

        search = state wall_and_buoy
        buoy = state wall_buoy_survey_def 
        #buoy = state simple_move_def(:x_speed => 0, :y_speed => 0, :timeout => 5, :heading => Math::PI/2, :depth => -1.5)
        stop = state simple_move_new_def(:timeout => 5, :depth => -2, :heading => Math::PI/2, :x_speed => 0, :y_speed => 0)
        search_continue = state wall_continue
        search_continue2 = state wall_left_new_def(:timeout => 20)
        back = state target_move_new_def(:finish_when_reached => true, :depth => -2, :delta_timeout => 5, :heading => -Math::PI * 0.75, :x => -22,     :y => 25,  :timeout => 150) 

        # start minefield search
        search_buoy1 = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -10, :y => 37, :depth => 1.5, :heading => Math::PI, :timeout => 90)
        search_buoy1a = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -10.5, :y => 37.5, :depth => 1.5, :heading => Math::PI, :timeout => 90)
        search_buoy1b = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -9.5, :y => 36.5, :depth => 1.5, :heading => Math::PI, :timeout => 90)

        search_buoy2 = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -15, :y => 35, :depth => 1.5, :heading => Math::PI, :timeout => 90)
        search_buoy2a = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -15.5, :y => 35.5, :depth => 1.5, :heading => Math::PI, :timeout => 90)
        search_buoy2b = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -14.5, :y => 34.5, :depth => 1.5, :heading => Math::PI, :timeout => 90)

        search_buoy3 = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -22, :y => 38, :depth => 1.5, :heading => Math::PI, :timeout => 90)
        search_buoy3a = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -22.5, :y => 38.5, :depth => 1.5, :heading => Math::PI, :timeout => 90)
        search_buoy3b = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -21.5, :y => 37.5, :depth => 1.5, :heading => Math::PI, :timeout => 90)

        search_buoy4 = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -12, :y => 37, :depth => 1.5, :heading => Math::PI/2, :timeout => 90)
        search_buoy4a = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -12.5, :y => 37.5, :depth => 1.5, :heading => Math::PI/2, :timeout => 90)
        search_buoy4b = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -11.5, :y => 36.5, :depth => 1.5, :heading => Math::PI/2, :timeout => 90)

        search_buoy5 = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -10, :y => 39, :depth => 1.5, :heading => 0, :timeout => 90)
        search_buoy5a = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -10.5, :y => 39.5, :depth => 1.5, :heading => 0, :timeout => 90)
        search_buoy5b = state target_move_new_def(:finish_when_reached => true, :delta_timeout => 2, :x => -9.5, :y => 38.5, :depth => 1.5, :heading => 0, :timeout => 90)

        buoy_detector = state buoy_detector_bottom_def

        search_buoy1.depends_on buoy_detector


        start out 
        transition out.success_event, to_wall
        transition to_wall.success_event, align
        transition align.success_event, search
        transition search.success_event, stop 
        transition stop.success_event, buoy
        transition buoy.success_event, search_continue
        transition search_continue.success_event, search_continue2
        transition search_continue2.success_event, back

        transition search_buoy1.success_event, search_buoy1a
        transition search_buoy1a.success_event, search_buoy1b
        transition search_buoy1b.success_event, search_buoy2
        transition search_buoy2.success_event, search_buoy2a
        transition search_buoy2a.success_event, search_buoy2b
        transition search_buoy2b.success_event, search_buoy3
        transition search_buoy3.success_event, search_buoy3a
        transition search_buoy3a.success_event, search_buoy3b
        transition search_buoy3b.success_event, search_buoy4
        transition search_buoy4.success_event, search_buoy4a
        transition search_buoy4a.success_event, search_buoy4b
        transition search_buoy4b.success_event, search_buoy5
        transition search_buoy5.success_event, search_buoy5a
        transition search_buoy5a.success_event, search_buoy5b


        forward search_buoy5b.success_event, success_event
    end
end






