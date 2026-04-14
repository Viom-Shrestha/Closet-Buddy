import json
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from PIL import Image, ImageDraw, ImageFont

from ai_models.classification.attribute_clip import extract_attributes
from ai_models.classification.clothing_classification import (
    map_category_from_subcategory,
    predict as predict_subcategory,
)
from ai_models.classification.occasion import predict_occasion_details
from ai_models.classification.shoe_metadata import classify_shoe_metadata
from ai_models.classification.weather import classify_clothing_weather
from ai_models.segmentation.segmentation_utill import segment_image
from ai_models.utils.auth_util import is_clothing, is_shoe
from ai_models.utils.color_extraction_util import extract_colors_with_names


class Command(BaseCommand):
    help = (
        "Run AI model predictions for one image and print model outputs "
        "(including confidence fields where available)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--image",
            required=True,
            help="Absolute or relative path to an input image file.",
        )
        parser.add_argument(
            "--shoe",
            action="store_true",
            help="Use shoe authentication/classification flow.",
        )
        parser.add_argument(
            "--no-segmentation",
            action="store_true",
            help="Skip segmentation and run prediction on the original image.",
        )
        parser.add_argument(
            "--json",
            action="store_true",
            help="Print output as compact JSON only.",
        )
        parser.add_argument(
            "--out-json",
            help="Optional file path to save full JSON output.",
        )
        parser.add_argument(
            "--out-png",
            help="Optional file path to save a PNG screenshot of the JSON output.",
        )

    def handle(self, *args, **options):
        image_path = Path(options["image"]).expanduser().resolve()
        is_shoe_mode = bool(options["shoe"])
        skip_segmentation = bool(options["no_segmentation"])
        as_json = bool(options["json"])
        out_json = options.get("out_json")
        out_png = options.get("out_png")

        if not image_path.exists():
            raise CommandError(f"Image not found: {image_path}")
        if not image_path.is_file():
            raise CommandError(f"Path is not a file: {image_path}")

        auth = is_shoe(image_path) if is_shoe_mode else is_clothing(image_path)
        auth_key = "is_shoe" if is_shoe_mode else "is_clothing"

        output = {
            "input_image": str(image_path),
            "mode": "shoe" if is_shoe_mode else "clothing",
            "auth": auth,
            "segmentation": {
                "attempted": not skip_segmentation,
                "ok": False,
                "segmented_url": None,
                "segmented_path": None,
                "error": None,
            },
        }

        if not auth.get(auth_key, False):
            output["status"] = "rejected"
            output["reason"] = "authentication_failed"
            self._print(output, as_json)
            self._save_artifacts(output, out_json, out_png)
            return

        selected_image_path = image_path
        if not skip_segmentation:
            try:
                with image_path.open("rb") as image_file:
                    segmented_url = segment_image(image_file)
                segmented_relative = str(segmented_url or "").replace(str(settings.MEDIA_URL), "", 1).lstrip("/\\")
                segmented_path = (Path(settings.MEDIA_ROOT) / segmented_relative).resolve()
                if segmented_path.exists():
                    selected_image_path = segmented_path
                    output["segmentation"].update(
                        {
                            "ok": True,
                            "segmented_url": segmented_url,
                            "segmented_path": str(segmented_path),
                        }
                    )
                else:
                    output["segmentation"].update(
                        {
                            "ok": False,
                            "segmented_url": segmented_url,
                            "error": "Segmented file was not found on disk.",
                        }
                    )
            except Exception as exc:
                output["segmentation"].update({"ok": False, "error": str(exc)})

        output["used_image"] = str(selected_image_path)

        colors = extract_colors_with_names(str(selected_image_path))
        output["color_model"] = colors

        if is_shoe_mode:
            category, subcategory, occasion, attributes = classify_shoe_metadata(selected_image_path)
            output["classification_model"] = {
                "category": category,
                "subcategory": subcategory,
                "confidence": None,
                "notes": "shoe_metadata currently does not expose confidence",
            }
            output["occasion_model"] = {
                "occasion": occasion,
                "confidence": None,
                "notes": "shoe_metadata provides occasion without confidence",
            }
            output["attribute_model"] = {"attributes": attributes}
        else:
            subcategory, subcategory_confidence = predict_subcategory(str(selected_image_path))
            category = map_category_from_subcategory(subcategory)
            occasion_details = predict_occasion_details(str(selected_image_path))
            attributes = extract_attributes(str(selected_image_path), subcategory)

            output["classification_model"] = {
                "category": category,
                "subcategory": subcategory,
                "confidence": float(subcategory_confidence),
            }
            output["occasion_model"] = occasion_details
            output["attribute_model"] = {"attributes": attributes}

        weather_details = classify_clothing_weather(
            str(selected_image_path),
            category=output["classification_model"]["category"],
            subcategory=output["classification_model"]["subcategory"],
        )
        output["weather_model"] = weather_details
        output["status"] = "ok"

        self._print(output, as_json)
        self._save_artifacts(output, out_json, out_png)

    def _print(self, payload, as_json):
        if as_json:
            self.stdout.write(json.dumps(payload, indent=2))
            return

        self.stdout.write(json.dumps(payload, indent=2))

    def _save_artifacts(self, payload, out_json, out_png):
        rendered = json.dumps(payload, indent=2)

        if out_json:
            json_path = Path(out_json).expanduser().resolve()
            json_path.parent.mkdir(parents=True, exist_ok=True)
            json_path.write_text(rendered, encoding="utf-8")
            self.stdout.write(f"Saved JSON: {json_path}")

        if out_png:
            png_path = Path(out_png).expanduser().resolve()
            png_path.parent.mkdir(parents=True, exist_ok=True)
            self._write_text_png(rendered, png_path)
            self.stdout.write(f"Saved PNG screenshot: {png_path}")

    def _write_text_png(self, text: str, output_path: Path):
        font = ImageFont.load_default()
        lines = text.splitlines() or [""]
        max_chars = max(len(line) for line in lines)

        char_w = 7
        line_h = 14
        pad = 20
        width = max(800, min(2600, (max_chars * char_w) + (pad * 2)))
        height = max(300, (len(lines) * line_h) + (pad * 2))

        image = Image.new("RGB", (width, height), color=(250, 250, 250))
        draw = ImageDraw.Draw(image)
        y = pad
        for line in lines:
            draw.text((pad, y), line, fill=(20, 20, 20), font=font)
            y += line_h

        image.save(output_path, format="PNG")
