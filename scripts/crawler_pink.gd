class_name PinkCrawler
extends CrawlerEnemy
## The pink crawler: the one that heals you when you kill it.

const KILL_HEAL := 2   ## half-hearts back for the kill (unless heal_on_kill is set)


func default_kill_heal() -> int:
	return KILL_HEAL
