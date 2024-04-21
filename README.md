# GodotSDK for QuickScope

QuickScope is a real time analytics platform for games. Empower your decision making, balancing, monetization and much more. Sign up for free today at [QuickScope.tech](https://quickscope.tech).

This SDK allows you to get up and running with QuickScope in Godot within minutes.

## Table of contents

* [Getting Started](#getting-started)
  + [Installation](#installation)
  + [Configuration](#configuration)
	+ [Advanced](#configuration-advanced)
* [Events](#events)
	+ [Structure](#events-structure)
* [Support](#support)
* [License](#license)

# Getting Started
## Installation
We recommend downloading the latest release from our [GitHub Releases](https://github.com/QuickScopeTech/GodotSDK/releases). If you need features that are still in beta, you can download the code straight from this repository and follow the same installation steps.

The Godot SDK is compatible with `Godot 4.0` and above.

1. Download and extract the latest stable release [QuickScope SDK](https://github.com/QuickScopeTech/GodotSDK/releases/latest/download).
2. Add the `quickscope_sdk` folder into your projects `addons` folder.
3. Once Godot has finished importing the addon, navigate to `Project > Project Settings > Plugins Tab` and in the list of Plugins find `QuickScopeSDK`. Ensure the plugin is enabled by clicking the `Enable` checkbox.
	+ This will add an autoload called `QuickScopeSDK`. This is how you can interact with the SDK from anywhere in your project. If you disable or remove this autoload, the SDK will not function.
4. In an autoload or entry point into your game call the SDK `init` function with your projects ID.
```gdscript
func _ready():
	QuickScopeSDK.init("01HVWT4VF7AH1234567890")
```
5. 🎉 Start gaining insight into how people play your game!

## Configuration

When initializing the SDK you can provide optional parameters to further customize the setup.

```gdscript

init(project_id: String, app_version := "", user_id := "", session_events := true)
```


| Name                       | Default value         | Description |
| ---------------------------|-----------------------|-------------|
|project_id| "" |Your project id which can be found in your QuickScope dashboard.
| app_version               | project version | Sets an app version for all events. By default this is retrieved from your projects `application/config/version`.                                                    |
| user_id                  | `OS.get_unique_id()` | How to identify the user attached to any events. If your QuickScope project is configured to be Session Based, this will be further anonymized by the QuickScope API.                          |
| session_events            | true            | Whether to automatically create a `session_started` and `session_ended` event for each play session.

### Advanced

Once the SDK has been initialized there are a few other options which can be changed during runtime.

| Name                       | Default value         | Description |
| ---------------------------|-----------------------|-------------|
|platform|`OS.get_name()`|The OS name, e.g. `Windows` |
|platform_version|`OS.get_version()`|The OS version, e.g. `10.0.19045` |
|default_level|"none"|Used to set a default "level" parameter for events. This can be updated everytime a new level is loaded to add more rich context.|

An example of updating the default level when a new level has been loaded could look like this:

```gdscript
func _ready():
	# Set the default level event to the new level or map which was loaded
	QuickScopeSDK.default_level = "rainbow_road"
	
	# triggering an event now will automatically have the "level" parameter attached as "rainbow_road"
	QuickScopeSDK.event("level_loaded")

```

Levels can also be used for non-gameplay categorization. Values could be something like "main_menu", "settings", "gameover_screen" etc. It is just a field to help determine where the event happened.


# Events

Events are at the core of QuickScope. They give you insight into how your players are interacting with your game. As every game is different, QuickScope doesn't come with a list of predefined events, instead you're free to fully customize how you want to track behavior.

```gdscript
func on_player_died(player: Player, killed_by: Enemy):
	# handle animations etc...
	# track this event
	QuickScopeSDK.event("player_died", {"killer": killed_by.name}, {"player_lvl": player.level, "killer_hp": killed_by.health})
	# reset game state, show gameover screen etc..
	
```

Thats it! Your QuickScope dashboard will start showing these events allowing you to make informed decisions about your game. Some questions that can now be answered by this one single event are:


> * Is there an overtuned enemy who is killing more players than any other enemy?
> * Is there an undertuned enemy who needs to be more dangerous?
> * Is the enemy mostly killing players within a certain level range?
> * Are the fights close and engaging or are the players getting one shot?

This is just an example of how one line of code can give you visibility into how players are playing your game.

## Structure

Events are created with 3 main arguments: Name, Metadata and Metrics. The full event function signature looks like this:

`event(name: String, metadata: Dictionary = {}, metrics: Dictionary = {}, level: String = "", ts: String = "")`

### Name

Name is the primary way you define an event. Some examples could be `player_died`, `level_completed`, `enemy_killed`, `boss_defeated` etc. but there is no restriction or limit to the number of events you create. We recommend you create a global constants file to define all your games events. See the [example quickscope events file](https://github.com/QuickScopeTech/GodotSDK/blob/main/event_reference_example.gd) for a reference.

### Metadata

Metadata allows you to store key value strings with an event. This is useful to provide more context around what triggered the event. We recommend trying to keep metadata limited to only the most important information relating to the event being triggered. For example, if the event is about a player picking up the item, relevant metadata might be the item being picked up and its rarity. As metadata is limited to strings only, we can store the quantity and value of the item picked up in Metrics.

### Metrics

Metrics allow you to store key value numbers with an event. Similar to metadata, this allows you to give even more actionable context to an event. For our item being picked up example, we could store the numeric quantity and value of the item.

### Examples

Putting it all together, here are some example events:

```gdscript

# player picking up an item
QuickScopeSDK.event(GameEvent.ITEM_PICKED_UP, {"item_name": item.name, "item_rarity": item.rarity}, {"item_value": item.value, "item_quantity": item.quantity})

# player killing enemies in the badlands
QuickScopeSDK.default_level = "badlands"
QuickScopeSDK.event(GameEvent.ENEMY_DEFEATED, {"enemy": enemy.name, "weapon": player.weapon.name}, {"player_level": player.level, "player_hp": player.hp })

# if your game has a large number of enemies being killed at once, this event could also be aggregated
QuickScopeSDK.event(GameEvent.ENEMIES_DEFEATED, {"enemy": enemy.type, "weapon": player.weapon.name}, {"enemies_killed": len(enemies_killed), "player_level": player.level, "player_hp": player.hp })

# player making an in app purchase
QuickScopeSDK.default_level = "iap_store"
QuickScopeSDK.event(GameEvent.IAP_STARTED, {"iap_item": item.id}, {"iap_value": item.price})
# iap flow ...
QuickScopeSDK.event(GameEvent.IAP_COMPLETE, {"iap_item": item.id}, {"iap_value": item.price})

```

### Optional

Optional event arguments are `level` and `ts`. `level` overrides whatever you have configured as `default_level` and `ts` overrides the timestamp used for the event. By default the `ts` is `Time.get_datetime_string_from_system(true)`.

# Support

If you have a problem with the SDK or a compatibility issue with your Godot game, please open an issue in Github. If your issue is related to the QuickScope platform itself, please visit [QuickScope Support](https://help.quickscope.tech).

# License

This project is licensed under the **MIT license**.

See [LICENSE](LICENSE) for more information.
