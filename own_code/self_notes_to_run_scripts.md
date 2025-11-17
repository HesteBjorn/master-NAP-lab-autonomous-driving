Setup env:
`source own_code/setup_env.sh --start-carla --enable-debug` 

Run a scenario:

`python leaderboard/leaderboard/leaderboard_evaluator_local.py     --routes=leaderboard/data/routes_devtest.xml     --track=SENSORS     --agent=team_code/sensor_agent.py     --agent-config=own_code/checkpoints/tfpp_all_towns_seed0     --checkpoint=outputs/debug_alltowns_seed0.json     --repetitions=1     --port=2000     --traffic-manager-port=2500     --traffic-manager-seed=0`

Run with video:

`own_code/run_with_debug_video.sh \
    --routes-file leaderboard/data/routes_devtest.xml \
    --command "python leaderboard/leaderboard/leaderboard_evaluator_local.py \
        --routes=leaderboard/data/routes_devtest.xml \
        --track=SENSORS \
        --agent=team_code/sensor_agent.py \
        --agent-config=own_code/checkpoints/tfpp_all_towns_seed0 \
        --checkpoint=outputs/debug_alltowns_seed0.json \
        --repetitions=1 \
        --port=2000 \
        --traffic-manager-port=2500 \
        --traffic-manager-seed=0" \
    --fps 12`


If VScode exits the terminal and out need crash output, pipe command with `|| read -p "Press enter to continue"`
