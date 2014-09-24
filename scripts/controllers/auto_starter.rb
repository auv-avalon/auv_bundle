require 'models/profiles/main'


State.soft_timeout = nil # 20min (timeout in sec)
State.timeout = nil #indicator  IF we have a timeout

State.current_mode = nil 
State.current_submode = nil
State.run_start = nil
State.last_navigation_task = nil
State.localization_task = nil
State.lowlevel_substate  = -1
State.lowlevel_state = -1
State.position = {:x => 0, :y => 0, :z => 0}
State.current_action = nil
State.current_state = ["Initializing"]
#Define the possible modes that can be set
#State.navigation_mode = ["drive_simple_def","buoy_def", "pipeline_def", "wall_right_def"]

#State.navigation_mode = [nil,"drive_simple_def","minimal_demo", "minimal_demo_once","target_move_def","buoy_def", "pipeline_def", "wall_right_def", "target_move_def", "pipe_ping_pong","ping_pong_pipe_wall_back_to_pipe","rocking"]
State.navigation_mode = [nil,"drive_simple_new_def"]

def check_for_switch
    new_state = State.navigation_mode[State.lowlevel_substate]
    if(State.timeout)
        new_state = "simple_move_new_def(:timeout => 300, depth => 100)" 
    end
    
    #####  Checking wether we can start localication or not ############
    if State.lowlevel_state == 5 or State.lowlevel_state == 3 #or State.lowlevel_state == 2
        hb_running = false
        begin
            t = Orocos::TaskContext.get "hbridge_writer"
            hb_running = t.running?
        end
        if State.localization_task.nil? and hb_running
            nm, _ = Robot.send("localization_def!")
            State.localization_task = nm.as_service
        end
    else
        if State.localization_task
            State.localization_task = nil
            Roby.plan.unmark_mission(State.localization_task.task)
        end
    end


    #######################  Checking wether we can start some behaviour  ######################
    if State.lowlevel_state == 5 or State.lowlevel_state == 3
        #Make sure nothing is running so far to prevent double-starting
        if State.current_mode.nil?
            #Check if the submode is a valid one
            if(new_state)
                Robot.info "starting navigation mode #{new_state}, we are currently at #{State.current_mode}"
                State.current_submode = State.lowlevel_substate
                nm, _ = Robot.send("#{new_state}!")
                #pp nm
                State.current_mode = nm.as_service
            elsif
                if State.lowlevel_substate != 0
                    Robot.info "Cannot Start unknown substate!!!!! -#{new_state}-"
                end
            end

            if(State.soft_timeout?)
                State.run_start = Time.now
            end
        end
    end
end

def check_for_mission_timeout
    if(State.soft_timeout? and State.run_start)
        if(Time.now - State.run_start > State.soft_timeout )
            if (Time.now - State.run_start < (State.soft_timeout + 5))
                Robot.info "Mission Timeout, Exiting Roby, surfacing NOW"
                State.timeout = true
                #begin
                #    Orocos::TaskContext.get('hbridge_writer').stop
                #rescue Exception => e
                #    Robot.info "Error #{e} during the stop of hbridges occured"
                #end
            end
            #Roby.engine.quit
            #if(Time.now - State.run_start > (State.soft_timeout + 30))
            #    Roby.engine.force_quit
            #end
        end
    end
end

#Reading the Joystick task to react on changes if an statechage should be done...
Roby.every(0.1, :on_error => :disable) do
    #Check wether we should stop an current operation mode
    if (State.lowlevel_state != 5 and  State.lowlevel_state != 3) or ((State.lowlevel_substate != State.current_submode) and State.current_submode)
        if State.current_mode
            Roby.plan.unmark_mission(State.current_mode.task)
            last_navigation_task = State.current_mode.task
            State.current_mode = nil
            State.current_submode = nil
        end
    end

    safe_mode = false

    #Workaround for someting withing roby
    if safe_mode
        if last_navigation_task
            last_navigation_task = nil if !last_navigation_task.plan # WORKAROUND: we're waiting for the task to be GCed by Roby before injecting the next navigation mode
        elsif 
            check_for_switch
        end
    else
        check_for_switch
    end

    check_for_mission_timeout
end
