class_name History
extends RefCounted
## What the player is told of the real events behind a mission: a note before it and what really
## happened after it. Every statement here is in the design's table of sources
## (docs/superpowers/specs/2026-11-12-historical-campaign-design.md, "Historical notes"). To say
## something new, put it in that table with its source first.

const NOTES := {
	"guadarrama": {
		"before": "The end of May 1937. The Republic attacks towards Segovia through the Sierra de Guadarrama, to draw Franco's army away from Bilbao. Hemingway set For Whom the Bell Tolls in this offensive: a dynamiter sent behind the lines to blow a bridge as the attack begins. The bridge here is his, not history's. The Dynamiter and the Marksman are invented too, here and in every mission.",
		"after": "The attack reached La Granja and was thrown back within a week. It held up the advance on Bilbao by about two weeks.",
		"sources": ["https://en.wikipedia.org/wiki/Segovia_Offensive"],
	},
	"teruel": {
		"before": "December 1937. The Republic attacks Teruel in falling snow, with no bombardment to announce it. A blizzard follows, and the cold goes to eighteen below. The raid on this depot is invented.",
		"after": "The town fell to the Republic, and was lost again in February 1938.",
		"sources": ["https://en.wikipedia.org/wiki/Battle_of_Teruel"],
	},
	"carchuna": {
		"before": "May 1938. 308 Asturian soldiers, taken prisoner when the north fell, are held in the fort of Carchuna on the Granada coast, close behind the front. On the 16th four officers escaped to the Republican lines and told what they knew. On the 23rd, 35 volunteers, five of them from the International Brigades, cross by launch from Castell de Ferro. Here the two of you go in ahead of them, and one officer stands for the 308.",
		"after": "The raiders took the fort and led the prisoners towards the Republican lines in two columns, with an artillery barrage to cover them. Twenty-five chose to stay behind.",
		"sources": ["https://vscw.ca/en/node/345"],
	},
	"volkhov": {
		"before": "Winter 1941–42. The División Azul, Spanish volunteers serving in the German army as its 250th Infantry Division, holds a stretch of the Volkhov front. Spanish Republicans in exile in the Soviet Union served in Soviet guerrilla units in this war, and some died fighting near Leningrad. This raid is invented: the two of you in Soviet service now, and Spaniards on the other side of the snow.",
		"after": "The División Azul stayed on the Volkhov until August 1942, when it was moved north to the siege lines round Leningrad.",
		"sources": ["https://en.wikipedia.org/wiki/Blue_Division",
				"https://www.ninosderusia.org/wp-content/uploads/2026/02/Relacion-Espanoles-Caidos-en-Ejercito-Sovietico-PFM.pdf"],
	},
}


## The note shown with the mission's briefing; "" when it has none.
static func before(id: String) -> String:
	return NOTES.get(id, {}).get("before", "")


## What really happened, shown after a win; "" when it has none.
static func after(id: String) -> String:
	return NOTES.get(id, {}).get("after", "")


static func sources(id: String) -> PackedStringArray:
	return PackedStringArray(NOTES.get(id, {}).get("sources", []))
