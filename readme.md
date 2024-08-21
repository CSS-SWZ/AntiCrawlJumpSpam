# AntiCrawlJumpSpam
Prevents jump spam in crawlspace

The plugin counts the number of invalid jumps within a certain time. If the player has reached the maximum number of jumps, the plugin starts to spam jumps, freezing the player.

* Number of invalid jumps = sm_acjs_jumps_max
* Time for jumpspam detection = last_jump_time + (sm_acjs_jumps_max * sm_acjs_cooldown)
* Freeze time = sm_acjs_freeze_delay
* Block time is also calculated as jumpspam detection time, also if it has not expired, it increases when the player freezes and when the player jumps.

# Configure this
The default settings are good but you can change them

```plugin.AntiCrawJumpSpam.cfg
// The time interval that defines a jump as invalid
// -
// Default: "0.4"
// Minimum: "0.100000"
// Maximum: "0.500000"
sm_acjs_cooldown "0.4"

// Enable/Disable crawlspace jump spam prevention
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_acjs_enable "1"

// Client freeze time after a jumpspam attempt being blocked
// -
// Default: "0.5"
// Minimum: "0.010000"
// Maximum: "2.000000"
sm_acjs_freeze_delay "0.5"

// Number of invalid jumps to start blocking jumpspams
// -
// Default: "3"
// Minimum: "1.000000"
// Maximum: "10.000000"
sm_acjs_jumps_max "3"

```