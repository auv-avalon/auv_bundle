require 'models/profiles/main'


State.soft_timeout = nil # 20min (timeout in sec)

State.current_mode = nil 
State.current_submode = nil
State.run_start = nil
State.last_navigation_task = nil
State.localization_task = nil
State.lowlevel_substate  = -1
State.lowlevel_state = -1

#Define the possible modes that can be set
#State.navigation_mode = ["drive_simple_def","buoy_def", "pipeline_def", "wall_right_def"]

#State.navigation_mode = [nil,"drive_simple_def","minimal_demo", "minimal_demo_once","target_move_def","buoy_def", "pipeline_def", "wall_right_def", "target_move_def", "pipe_ping_pong","ping_pong_pipe_wall_back_to_pipe","rocking"]
State.navigation_mode = [nil,"drive_simple_def","minimal_demo", "minimal_demo_once", "advanced_demo", "advanced_demo_once"]

def check_for_switch
    #####  Checking wether we can start localication or not ############
    if State.lowlevel_state == 5 or State.lowlevel_state == 3 #or State.lowlevel_state == 2
        if State.localization_task.nil? and State.navigation_mode[State.lowlevel_substate]
            nm, _ = Robot.send("localization_def!")
            State.localization_task = nm.as_service
        end
    else
        if State.localization_task
            Roby.plan.unmark_mission(State.localization_task.task)
            State.localization_task = nil
        end
    end


    #######################  Checking wether we can start some behaviour  ######################
    if State.lowlevel_state == 5 or State.lowlevel_state == 3
        #Make sure nothing is running so far to prevent double-starting
        if State.current_mode.nil?
            #Check if the submode is a valid one
            if(State.navigation_mode[State.lowlevel_substate])
                Robot.info "starting navigation mode #{State.navigation_mode[State.lowlevel_substate]}, we are currently at #{State.current_mode}"
                State.current_submode = State.lowlevel_substate
                nm, _ = Robot.send("#{State.navigation_mode[State.lowlevel_substate]}!")
                #pp nm
                State.current_mode = nm.as_service
            elsif
                if State.lowlevel_substate != 0
                    Robot.info "Cannot Start unknown substate!!!!! -#{State.navigation_mode[State.lowlevel_substate]}-"
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
                begin
                    Orocos::TaskContext.get('hbridge_writer').stop
                rescue Exception => e
                    Robot.info "Error #{e} during the stop of hbridges occured"
                end
            end
            Roby.engine.quit
            if(Time.now - State.run_start > (State.soft_timeout + 30))
                Roby.engine.force_quit
            end
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
