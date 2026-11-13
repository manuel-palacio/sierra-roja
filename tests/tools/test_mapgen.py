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


class Water(unittest.TestCase):
    def _z(self, lines):
        placed = [line for line in lines if line.startswith("transform")][0]
        return float(placed.rstrip(")").split(", ")[-1])

    def test_water_to_the_north_lies_north(self):
        m = mapgen.mission(WATER=("north", -30, 0.4))
        lines = mapgen.water_nodes(m)
        self.assertIn('[node name="Water" type="MeshInstance3D" parent="Scenery"]', lines)
        self.assertLess(self._z(lines), -30)

    def test_sea_still_means_water_to_the_south(self):
        m = mapgen.mission(SEA=(33, 0.35))
        lines = mapgen.water_nodes(m)
        self.assertIn('[node name="Sea" type="MeshInstance3D" parent="Scenery"]', lines)
        self.assertEqual(self._z(lines), 33 + 76)

    def test_no_water_no_nodes(self):
        self.assertEqual(mapgen.water_nodes(mapgen.mission()), [])

    def test_water_on_a_side_that_is_not_one_is_refused(self):
        with self.assertRaises(ValueError):
            mapgen.mission(WATER=("west", 0, 0))


if __name__ == "__main__":
    unittest.main()
