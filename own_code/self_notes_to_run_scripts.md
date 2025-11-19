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


Download small portion of data (1 type of scenario):
`download_short_scenario.sh`


Run short training loop:

` export CARLA_ROOT=~/software/CARLA_Leaderboard_20
./own_code/short_train.sh data_short outputs/debug_short
`



Inspect losses from tensorboard:

`tensorboard --logdir outputs/debug_short/short_debug_vscode || read -p "e"`


Run local eval on 3 Bench2Drive routes (after setup_env):

`bash Bench2Drive/leaderboard/scripts/run_evaluation_short.sh  \
    --agent team_code/sensor_agent.py \
    --config own_code/checkpoints/tfpp_all_towns_seed0 \
    --gpu 0 || read -p "enter to continue"`