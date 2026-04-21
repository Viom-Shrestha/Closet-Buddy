from transformers import CLIPProcessor, CLIPModel
from PIL import Image
import torch

device = "cuda" if torch.cuda.is_available() else "cpu"

MODEL_NAME = "patrickjohncyh/fashion-clip"

clip_model = CLIPModel.from_pretrained(MODEL_NAME).to(device)
clip_processor = CLIPProcessor.from_pretrained(MODEL_NAME, use_fast=True)

# GLOBAL GROUPS 

PATTERN_PROMPTS = {
    "solid": "solid color clothing",
    "striped": "striped pattern clothing",
    "floral": "floral pattern clothing",
    "plaid": "plaid pattern clothing",
    "checked": "checked pattern clothing",
    "graphic": "graphic print clothing"
}

FABRIC_PROMPTS = {
    "cotton": "cotton fabric clothing",
    "denim": "denim fabric clothing",
    "wool": "wool fabric clothing",
    "leather": "leather material clothing",
    "linen": "linen fabric clothing",
    "silk": "silk fabric clothing",
    "knit": "knit fabric clothing"
}

STYLE_PROMPTS = {
    "casual": "casual style clothing",
    "formal": "formal style clothing",
    "sporty": "sporty style clothing",
    "streetwear": "streetwear style clothing",
    "vintage": "vintage style clothing"
}

FIT_PROMPTS = {
    "slim": "slim fit clothing",
    "regular": "regular fit clothing",
    "loose": "loose fit clothing",
    "oversized": "oversized clothing"
}

#  UPPER BODY 

SLEEVE_PROMPTS = {
    "long sleeve": "long sleeve top",
    "short sleeve": "short sleeve top",
    "sleeveless": "sleeveless top"
}

NECKLINE_PROMPTS = {
    "round neck": "round neck top",
    "v neck": "v neck top",
    "collared": "collared shirt",
    "hooded": "hooded top"
}

#  LOWER BODY 

LOWER_LENGTH_PROMPTS = {
    "full length": "full length pants",
    "cropped": "cropped pants",
    "knee length": "knee length shorts",
    "mini": "mini skirt",
    "midi": "midi skirt"
}

#  FULL BODY 

DRESS_LENGTH_PROMPTS = {
    "mini dress": "mini dress",
    "midi dress": "midi dress",
    "maxi dress": "long maxi dress"
}

#  SHOES 

SHOE_TYPE_PROMPTS = {
    "sneakers": "sneakers athletic running shoes trainers",
    "formal shoes": "formal leather dress shoes office shoes oxford derby",
    "boots": "boots ankle boots leather boots winter boots",
    "sandals": "sandals open toe footwear summer sandals",
    "heels": "high heels pumps stilettos women's heels",
    "loafers": "loafers slip on casual formal shoes",
    "slippers": "slippers indoor home footwear",
    "flip flops": "flip flops beach sandals casual",
    "sports shoes": "sports running gym training shoes",
}

SHOE_MATERIAL_PROMPTS = {
    "leather": "leather shoes genuine leather formal footwear",
    "canvas": "canvas shoes lightweight casual sneakers",
    "suede": "suede leather shoes soft texture",
    "synthetic": "synthetic material shoes artificial leather",
    "mesh": "mesh breathable sports shoes running shoes",
    "rubber": "rubber footwear waterproof shoes",
    "knit": "knit fabric shoes flexible sneakers",
}

SHOE_USAGE_PROMPTS = {
    "sports": "sports running gym training athletic shoes",
    "casual": "casual everyday sneakers comfortable shoes",
    "formal": "formal office business dress shoes",
    "outdoor": "outdoor hiking trekking shoes durable",
    "party": "party wear stylish fashionable shoes",
    "home": "home indoor slippers comfortable",
}



# Core scoring function
# This function takes an image and a dictionary of prompts, and returns a dictionary of scores for each prompt based on how well the image matches the prompt.
def _score_prompts(image, prompt_dict):

    labels = list(prompt_dict.keys())
    texts = list(prompt_dict.values())

    inputs = clip_processor(
        images=image,
        text=texts,
        return_tensors="pt",
        padding=True
    ).to(device)

    with torch.no_grad():
        outputs = clip_model(**inputs)

    probs = outputs.logits_per_image.softmax(dim=1)[0]

    scores = {labels[i]: float(probs[i]) for i in range(len(labels))}

    return scores


def _pick_best(image, prompt_dict):
    scores = _score_prompts(image, prompt_dict)
    best = max(scores, key=scores.get)
    return best


def _pick_top_k(image, prompt_dict, k=1, threshold=0.30):
    scores = _score_prompts(image, prompt_dict)
    sorted_items = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [item[0] for item in sorted_items[:k] if item[1] > threshold]


# Main attribute extraction function for clothing items.

UPPER_BODY = [
    "Shirt","Tee","Blouse","Jacket","Coat","Hoodie","Sweater"
]

LOWER_BODY = [
    "Pants","Jeans","Shorts","Skirt"
]

FULL_BODY = [
    "Dress","Jumpsuit"
]


def extract_attributes(image_path, subcategory):

    image = Image.open(image_path).convert("RGB")

    attributes = []

    #  GLOBAL 
    attributes.append(_pick_best(image, PATTERN_PROMPTS))
    attributes.append(_pick_best(image, STYLE_PROMPTS))
    attributes.append(_pick_best(image, FIT_PROMPTS))

    fabric = _pick_top_k(image, FABRIC_PROMPTS, k=1)
    attributes.extend(fabric)

    #  CATEGORY SPECIFIC 
    if subcategory in UPPER_BODY:
        attributes.append(_pick_best(image, SLEEVE_PROMPTS))
        attributes.append(_pick_best(image, NECKLINE_PROMPTS))

    elif subcategory in LOWER_BODY:
        attributes.append(_pick_best(image, LOWER_LENGTH_PROMPTS))

    elif subcategory in FULL_BODY:
        attributes.append(_pick_best(image, DRESS_LENGTH_PROMPTS))
        attributes.append(_pick_best(image, SLEEVE_PROMPTS))

    # remove duplicates
    attributes = list(set(attributes))

    return attributes



# SHOE ATTRIBUTE EXTRACTOR

def extract_shoe_details(image_path):

    image = Image.open(image_path).convert("RGB")

    shoe_type = _pick_best(image, SHOE_TYPE_PROMPTS)
    shoe_material = _pick_best(image, SHOE_MATERIAL_PROMPTS)
    usage = _pick_best(image, SHOE_USAGE_PROMPTS)

    attributes = [shoe_type, shoe_material, usage]

    return {
        "shoe_type": shoe_type,
        "material": shoe_material,
        "usage": usage,
        "attributes": attributes,
    }


def extract_shoe_attributes(image_path):
    details = extract_shoe_details(image_path)
    return details["attributes"]
