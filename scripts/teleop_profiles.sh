#!/usr/bin/env bash
# Profile definitions for teleop.sh

# Add profile names here.
PROFILES=("default")

# Defaults for "default" profile.
profile_default_robot_type="so101_follower"
profile_default_teleop_type="so101_leader"
profile_default_robot_port="/dev/follower_arm_1"
profile_default_teleop_port="/dev/leader_arm_1"
profile_default_robot_id="my_so101_follower_1"
profile_default_teleop_id="my_so101_leader_1"
profile_default_cam_top="/dev/top_cam_1"
profile_default_cam_front="/dev/follower_cam_1"
profile_default_cam_width="640"
profile_default_cam_height="480"
profile_default_cam_fps="30"
profile_default_cam_fourcc="MJPG"
