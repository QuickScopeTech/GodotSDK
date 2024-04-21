# This file is an example of how you could save a list of your events
# for use throughout your project. This allows you to use the editors autocomplete
# along with avoiding accidental typo's when referencing event names as strings.

class_name GameEvent

const LEVEL_COMPLETED := "level_completed"
const LEVEL_FAILED := "level_failed"
const LEVEL_STARTED := "level_started"

const PLAYER_GAINED_COINS = "player_got_coins"
const PLAYER_GAINED_POWERUP = "player_got_powerup"
const PLAYER_LEVELED_UP = "player_lvled_up"
const PLAYER_DIED := "player_died"

const ITEM_PICKED_UP = "item_picked_up"

const BOSS_DEFEATED = "boss_defeated"
const ENEMY_DEFEATED = "enemy_defeated"

const IAP_STARTED = "iap_started"
const IAP_COMPLETE = "iap_complete"

# Example Usage:
# QuickScopeSDK.event(GameEvent.ENEMY_DEFEATED, {"enemy": enemy.name})
# QuickScopeSDK.event(GameEvent.PLAYER_GAINED_COINS, {"coins": coins_gained})
