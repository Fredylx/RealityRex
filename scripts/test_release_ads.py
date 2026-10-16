import unittest
from check_release_ads import validate


class ReleaseAdsTests(unittest.TestCase):
    def setUp(self):
        # Synthetic IDs for configuration validation only; never configure a build with these.
        self.info = {"GADApplicationIdentifier": "ca-app-pub-1234567890123456~1234567890", "ADMOB_BANNER_UNIT_ID": "ca-app-pub-1234567890123456/1234567890"}

    def test_production_format(self):
        self.assertEqual(validate(self.info), [])

    def test_missing_unresolved_and_wrong_type(self):
        for value in [None, "", "$(GAD_APPLICATION_IDENTIFIER)", 123, "ca-app-pub-invalid"]:
            with self.subTest(value=value):
                self.assertTrue(validate({**self.info, "GADApplicationIdentifier": value}))

    def test_google_test_ids(self):
        for key in self.info:
            self.assertTrue(validate({**self.info, key: self.info[key].replace("1234567890123456", "3940256099942544")}))

    def test_mismatched_publishers(self):
        self.assertTrue(validate({**self.info, "ADMOB_BANNER_UNIT_ID": "ca-app-pub-1111111111111111/1234567890"}))

    def test_reversed_id_types(self):
        self.assertTrue(validate({"GADApplicationIdentifier": self.info["ADMOB_BANNER_UNIT_ID"], "ADMOB_BANNER_UNIT_ID": self.info["GADApplicationIdentifier"]}))


if __name__ == "__main__":
    unittest.main()
