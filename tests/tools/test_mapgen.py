"""The map generator refuses what it does not know, so a misspelt table cannot write a scene
that quietly looks or plays otherwise than meant.

    python3 -m unittest discover -s tests/tools -t .
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import mapgen  # noqa: E402


class Refusals(unittest.TestCase):
    def test_unknown_season_is_refused(self):
        with self.assertRaises(ValueError) as caught:
            mapgen.mission(SEASON="winter")
        self.assertIn("SEASON", str(caught.exception))
        self.assertIn("winter", str(caught.exception))

    def test_unknown_light_and_dress_are_refused(self):
        with self.assertRaises(ValueError) as caught:
            mapgen.mission(LIGHT="noon")
        self.assertIn("LIGHT", str(caught.exception))
        with self.assertRaises(ValueError) as caught:
            mapgen.mission(DRESS="tropics")
        self.assertIn("DRESS", str(caught.exception))

    def test_known_values_pass(self):
        mapgen.mission()
        mapgen.mission(SEASON="snow", LIGHT="dusk", DRESS="russia")
        mapgen.mission(LIGHT="overcast", DRESS="spain_winter")
        mapgen.mission(NIGHT=True, LIGHT="predawn")

    def test_a_rescue_without_a_building_is_refused(self):
        with self.assertRaises(ValueError) as caught:
            mapgen.mission(OBJECTIVES=[{"kind": "rescue", "prisoner": (0, 0), "ground": 0.0, "hud": "h",
                                        "escort": "e", "marker": "m"}])
        self.assertIn("building", str(caught.exception))

    def test_an_unknown_objective_kind_is_refused(self):
        with self.assertRaises(ValueError):
            mapgen.mission(OBJECTIVES=[{"kind": "befriend"}])

    def test_a_whole_objective_passes(self):
        mapgen.mission(OBJECTIVES=[{"kind": "destroy", "hud": "h", "marker": "m", "done": "d"}])


if __name__ == "__main__":
    unittest.main()
