window.aleeCategoryGroups = [
  { id:'apparel', label:'Apparel', icon:'👕' },
  { id:'shoes', label:'Shoes', icon:'👟' },
  { id:'bags-luggage', label:'Bags & Luggage', icon:'👜' },
  { id:'consumer-electronics', label:'Consumer Electronics', icon:'📱' },
  { id:'mobile-accessories', label:'Mobile Accessories', icon:'🎧' },
  { id:'computer-office', label:'Computer & Office', icon:'💻' },
  { id:'home-appliances', label:'Home Appliances', icon:'🏠' },
  { id:'home-kitchen', label:'Home & Kitchen', icon:'🍳' },
  { id:'furniture', label:'Furniture', icon:'🛋️' },
  { id:'home-garden', label:'Home & Garden', icon:'🌿' },
  { id:'beauty-personal-care', label:'Beauty & Personal Care', icon:'💄' },
  { id:'health-medical', label:'Health & Medical', icon:'🩺' },
  { id:'mother-baby', label:'Mother & Baby', icon:'🍼' },
  { id:'toys-games', label:'Toys & Games', icon:'🧸' },
  { id:'sports-outdoors', label:'Sports & Outdoors', icon:'⚽' },
  { id:'food-grocery', label:'Food & Grocery', icon:'🛒' },
  { id:'jewellery-watches', label:'Jewellery & Watches', icon:'⌚' },
  { id:'vehicle-automotive', label:'Vehicle & Automotive', icon:'🚗' },
  { id:'machinery-tools', label:'Machinery & Tools', icon:'🔧' },
  { id:'electrical-lights', label:'Electrical & Lights', icon:'💡' },
  { id:'hardware-building', label:'Hardware & Building', icon:'🧰' },
  { id:'safety-industrial', label:'Safety & Industrial', icon:'🦺' },
  { id:'packaging-printing', label:'Packaging & Printing', icon:'📦' },
  { id:'pet-supplies', label:'Pet Supplies', icon:'🐾' },
  { id:'books-stationery', label:'Books & Stationery', icon:'📚' },
  { id:'agriculture', label:'Agriculture', icon:'🌱' },
  { id:'fashion-accessories', label:'Fashion Accessories', icon:'🧢' }
];

window.aleeCatalogTabs = [
  { id:'gadgets', label:'Gadgets & Audio' },
  { id:'watches', label:'Smart Watches' },
  { id:'beauty', label:'Beauty & Hair' },
  { id:'power', label:'Power & Tools' },
  { id:'phone', label:'Mobile phones' },
  { id:'fashion', label:'Fashion' },
  { id:'sport', label:'Sport' },
  { id:'t-shirt', label:'t shirt' }
];

const categoryDefinitions = [
  ['apparel', "Men's Wear", "Men's T-Shirt|Men's Shirt|Men's Denim|Men's Trouser|Men's Shorts|Men's Hoodie|Men's Jacket|Men's Suit|Men's Underwear|Men's Vest"],
  ['apparel', "Women's Wear", "Women's Frock|Women's Tops|Women's Saree|Women's Blouse|Women's Skirt|Women's Jeans|Women's Leggings|Women's Abaya|Women's Hijab|Women's Night Dress"],
  ['apparel', 'Kids Wear', 'Kids Boys Dress|Kids Girls Dress|Baby Frock|Baby Romper|School Uniform'],
  ['apparel', 'Other Apparel', 'Office Wear|Sportswear|Rain Coat|Sweater'],
  ['shoes', 'Footwear', 'Sneakers|Running Shoes|Casual Shoes|Formal Shoes|Loafers|Sandals|Slippers|Flip Flops|Boots|High Heels|Flat Shoes|Sports Shoes|Football Shoes|Cricket Shoes|Baby Shoes|School Shoes|Crocs|Safety Shoes'],
  ['bags-luggage', 'Bags & Luggage', 'Handbag|Shoulder Bag|Sling Bag|Backpack|School Bag|College Bag|Travel Bag|Suitcase|Trolley Bag|Laptop Bag|Wallet|Purse|Clutch|Baby Bag|Gym Bag|Lunch Bag'],
  ['consumer-electronics', 'Mobile Phones', 'Mobile Phone|Samsung Phone|iPhone|Xiaomi Phone|Vivo Phone|Oppo Phone'],
  ['consumer-electronics', 'Consumer Electronics', 'Tablet|Laptop|Desktop Computer|Smart TV|LED TV|Camera|DSLR Camera|Drone|Game Console|PS5|Xbox|Projector|Smart Watch|Smart Band|VR Headset|Printer|Scanner'],
  ['mobile-accessories', 'Mobile Accessories', 'Phone Cover|Back Cover|Tempered Glass|Charger|Fast Charger|Cable|Type-C Cable|Power Bank|Earbuds|AirPods|Headphone|Bluetooth Speaker|Memory Card|SIM Ejector|Phone Stand|Selfie Stick|Ring Light|Phone Holder'],
  ['computer-office', 'Computer & Office', 'Mouse|Wireless Mouse|Keyboard|Monitor|CPU|Hard Disk|SSD|Pendrive|Memory Card Reader|Webcam|Laptop Stand|Laptop Charger|Laptop Bag|Printer Ink|Office Table|Office Chair|File|Folder|Pen|Notebook|Stapler'],
  ['home-appliances', 'Home Appliances', 'Rice Cooker|Kettle|Electric Kettle|Blender|Mixer Grinder|Iron|Steam Iron|Stand Fan|Ceiling Fan|Table Fan|Washing Machine|Fridge|AC|Air Cooler|Vacuum Cleaner|Oven|Microwave|Toaster|Hair Dryer|Water Heater'],
  ['home-kitchen', 'Kitchen', 'Cooker|Non-Stick Pan|Frying Pan|Dinner Set|Plates|Cups|Water Bottle|Flask|Lunch Box|Storage Box|Spice Box'],
  ['home-kitchen', 'Bedroom & Bath', 'Bedsheet|Pillow|Pillow Cover|Curtain|Towel|Bath Towel|Mosquito Net'],
  ['home-kitchen', 'Cleaning', 'Door Mat|Cleaning Brush|Mop|Bucket|Dustbin'],
  ['furniture', 'Furniture', 'Sofa|Sofa Set|Bed|Single Bed|Double Bed|Wardrobe|Cupboard|Dining Table|Dining Chair|Office Table|Office Chair|Computer Table|Study Table|Shelf|Shoe Rack|TV Stand|Mattress|Bean Bag'],
  ['home-garden', 'Home & Garden', 'Indoor Plants|Artificial Plants|Flower Pot|Garden Tools|Water Pipe|Outdoor Chair|Outdoor Table|Garden Lights|Solar Lights|Mosquito Net|Door Mat|Wall Clock|Wall Sticker|Photo Frame|Mirror|Candle'],
  ['beauty-personal-care', 'Makeup', 'Lipstick|Lip Gloss|Foundation|Eyeliner|Mascara|Makeup Brush Set|Makeup Kit|Nail Polish|Nail Cutter Set'],
  ['beauty-personal-care', 'Skin Care', 'Face Wash|Face Cream|Night Cream|Serum|Toner|Face Mask'],
  ['beauty-personal-care', 'Hair & Personal Care', 'Perfume|Body Lotion|Shampoo|Conditioner|Hair Oil|Hair Color|Hair Dryer|Hair Straightener|Trimmer|Shaver'],
  ['health-medical', 'Health & Medical', 'Vitamins|Vitamin C|Protein Powder|Collagen|Face Mask|Hand Sanitizer|BP Machine|Sugar Machine|Thermometer|First Aid Kit|Spectacles|Sunglasses|Massage Machine|Neck Pillow|Knee Guard|Back Support Belt|Walking Stick'],
  ['mother-baby', 'Mother & Baby', 'Diapers|Baby Wipes|Baby Food|Milk Powder|Feeding Bottle|Baby Dress|Baby Shoes|Baby Toys|Baby Stroller|Baby Walker|Baby Bed|Baby Bath Tub|Baby Oil|Baby Shampoo|Baby Towel|School Bag|Water Bottle'],
  ['toys-games', 'Toys & Games', 'Remote Control Car|Remote Helicopter|Doll|Barbie Doll|Lego|Building Blocks|Puzzle|Board Game|Chess|Carrom|Ball|Football|Cricket Set|Cycle|Tricycle|Kite|Water Gun|Video Game|PS Game CD'],
  ['sports-outdoors', 'Sports & Outdoors', 'Cricket Bat|Cricket Ball|Football|Volleyball|Badminton Racket|Badminton Shuttle|Tennis Racket|Gym Dumbbell|Gym Gloves|Yoga Mat|Resistance Band|Cycle|Cycle Helmet|Fishing Rod|Fishing Net|Camping Tent|Sleeping Bag|Hiking Bag|Water Bottle'],
  ['food-grocery', 'Food & Grocery', 'Rice|Red Rice|Flour|Dhal|Chickpea|Spices|Turmeric|Chilli Powder|Milk Powder|Tea|Coffee|Sugar|Oil|Coconut Oil|Biscuits|Chocolate|Cake|Noodles|Pasta|Sauce|Ketchup|Soft Drinks|Juice|Dry Fruits|Cashew|Almonds'],
  ['jewellery-watches', 'Jewellery & Watches', 'Gold Necklace|Gold Plated Necklace|Earring|Stud|Ring|Wedding Ring|Bracelet|Bangle|Anklet|Chain|Pendant|Watch|Men\'s Watch|Women\'s Watch|Kids Watch|Smart Watch|Wall Clock'],
  ['vehicle-automotive', 'Vehicle & Automotive', 'Car Seat Cover|Car Polish|Car Shampoo|Car Vacuum|Bike Helmet|Full Face Helmet|Bike Cover|Bike Lock|Tyre|Tube|Battery|Horn|LED Light|Fog Light|Dash Cam|Car Phone Holder|Air Freshener|Wiper Blade'],
  ['machinery-tools', 'Machinery & Tools', 'Drill Machine|Drill Bit Set|Grinder|Angle Grinder|Hammer|Screwdriver Set|Wrench Set|Spanner|Pliers|Welding Machine|Generator|Water Pump|Water Motor|Air Compressor|Ladder|Measuring Tape'],
  ['electrical-lights', 'Electrical & Lights', 'LED Bulb|Tube Light|Ceiling Light|Wall Light|Table Lamp|Solar Panel|Solar Light|Switch|Socket|Multi Plug|Wire|Cable|Battery|Torch|Emergency Lamp|Extension Cord|Door Bell'],
  ['hardware-building', 'Hardware & Building', 'Door Lock|Padlock|Hinge|Door Handle|Paint|Paint Brush|Cement Tools|Trowel|Tap|Shower|Bathroom Fittings|Pipe|PVC Pipe|Tile Cutter|Sand Paper|Putty'],
  ['safety-industrial', 'Safety & Industrial', 'Safety Helmet|Safety Gloves|Safety Shoes|Safety Goggles|Fire Extinguisher|Face Mask|Hand Gloves|Rain Coat|Reflective Jacket|First Aid Box'],
  ['packaging-printing', 'Packaging & Printing', 'Cardboard Box|Packing Box|Packing Tape|Bubble Wrap|Gift Box|Gift Wrapping Paper|Ribbon|Label Sticker|Shopping Bag|Paper Bag'],
  ['pet-supplies', 'Pet Supplies', 'Dog Food|Cat Food|Dog Biscuit|Cat Litter|Pet Toys|Pet Cage|Pet Bed|Pet Shampoo|Pet Soap|Fish Tank|Fish Food|Bird Cage|Bird Food'],
  ['books-stationery', 'Books & Stationery', 'School Text Book|Novel|Story Book|Colouring Book|Note Book|CR Book|Exercise Book|Pen|Gel Pen|Pencil|Eraser|Geometry Box|Ruler|Calculator|Glue|Scissor|Art Paper|Water Colour|Crayon'],
  ['agriculture', 'Agriculture', 'Seeds|Vegetable Seeds|Fertilizer|Organic Fertilizer|Farming Tools|Mamoty|Water Tank|Plastic Tank|Animal Food|Chicken Food|Cow Food|Spray Bottle'],
  ['fashion-accessories', 'Fashion Accessories', 'Cap|Hat|Belt|Tie|Scarf|Gloves|Socks|Sunglasses|Umbrella|Key Tag|Hair Band|Hair Clip']
];

const categoryAliases = {
  'apparel-mens-t-shirt':['t-shirt','t shirt','tshirt','tee','mens t shirt','men t shirt'],
  'apparel-mens-shirt':['sirt','mens shirt','men shirt'],
  'apparel-mens-denim':['mens jeans','men jeans','jeans','denim jeans'],
  'apparel-womens-frock':['frock','dress','womens dress','ladies dress'],
  'apparel-womens-tops':['women top','ladies top'],
  'apparel-womens-jeans':['ladies jeans','womens denim'],
  'shoes-sneakers':['sneaker','fashion sneakers'],
  'consumer-electronics-samsung-phone':['samsung','galaxy'],
  'consumer-electronics-iphone':['apple phone','iphone mobile'],
  'consumer-electronics-xiaomi-phone':['xiaomi','redmi'],
  'consumer-electronics-vivo-phone':['vivo'],
  'consumer-electronics-oppo-phone':['oppo'],
  'mobile-accessories-earbuds':['ear bud','ear buds','tws','wireless earbuds'],
  'mobile-accessories-airpods':['air pod','air pods'],
  'mobile-accessories-phone-cover':['phone case','mobile cover','back cover'],
  'mobile-accessories-tempered-glass':['screen protector','phone glass'],
  'mobile-accessories-charger':['charging adapter','mobile charger'],
  'mobile-accessories-cable':['data cable','charging cable'],
  'computer-office-pendrive':['pen drive','usb drive','flash drive'],
  'home-appliances-electric-kettle':['electric water kettle'],
  'home-appliances-vacuum-cleaner':['vacuum','vacuum cleaner'],
  'beauty-personal-care-perfume':['fragrance','cologne'],
  'beauty-personal-care-hair-dryer':['hair blower'],
  'sports-outdoors-gym-dumbbell':['dumbbell','dumbbells'],
  'food-grocery-dhal':['dal','lentils'],
  'jewellery-watches-smart-watch':['smartwatch','smart watch'],
  'machinery-tools-drill-machine':['drill','electric drill'],
  'electrical-lights-led-bulb':['led light bulb','light bulb'],
  'books-stationery-note-book':['notebook','exercise book'],
  'health-medical-massage-machine':['massage gun','neck massager','facial massager'],
  'books-stationery-scissor':['scissors']
};

const slugifyCategory = value => value.toLowerCase().replace(/['’]/g, '').replace(/&/g, 'and').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
window.aleeCategories = categoryDefinitions.flatMap(([parent, section, labels]) => labels.split('|').map(label => {
  const id = `${parent}-${slugifyCategory(label)}`;
  return { id, label, parent, section, keywords:categoryAliases[id] || [] };
}));

window.aleeLegacyCategoryMap = {
  'womens-fashion':'apparel-womens-frock',
  'mens-fashion':'apparel-mens-shirt',
  'kids-fashion':'apparel-kids-boys-dress',
  'bags-purses':'bags-luggage-handbag',
  'shoes-footwear':'shoes-sneakers',
  'watches-accessories':'jewellery-watches-watch',
  jewelry:'jewellery-watches-gold-necklace',
  makeup:'beauty-personal-care-lipstick',
  'skin-care':'beauty-personal-care-face-cream',
  'hair-care':'beauty-personal-care-hair-dryer',
  perfumes:'beauty-personal-care-perfume',
  'personal-care':'beauty-personal-care-trimmer',
  'mobile-phones-accessories':'consumer-electronics-mobile-phone',
  'laptops-computers':'consumer-electronics-laptop',
  'headphones-earbuds':'mobile-accessories-earbuds',
  'smart-watches':'jewellery-watches-smart-watch',
  'chargers-cables':'mobile-accessories-charger',
  'home-decor':'home-kitchen-mop',
  'kitchen-appliances':'home-appliances-electric-kettle',
  bedding:'home-kitchen-bedsheet',
  furniture:'furniture-sofa',
  toys:'toys-games-doll',
  'baby-products':'mother-baby-baby-dress',
  'kids-school-items':'books-stationery-geometry-box',
  'gym-fitness':'sports-outdoors-gym-dumbbell',
  'travel-luggage':'bags-luggage-travel-bag',
  'outdoor-gear':'machinery-tools-drill-machine',
  'food-snacks':'food-grocery-biscuits',
  stationery:'books-stationery-note-book',
  beauty:'beauty-personal-care-lipstick',
  health:'health-medical-vitamins',
  gadgets:'mobile-accessories-earbuds',
  gadget:'mobile-accessories-earbuds',
  audio:'mobile-accessories-bluetooth-speaker',
  watches:'jewellery-watches-smart-watch',
  smartwatch:'jewellery-watches-smart-watch',
  phone:'consumer-electronics-mobile-phone',
  power:'machinery-tools-drill-machine',
  tool:'machinery-tools-drill-machine',
  sport:'sports-outdoors-gym-dumbbell',
  fashion:'apparel-womens-frock',
  't-shirt':'apparel-mens-t-shirt'
};

window.aleeSuggestProductCategory = value => {
  const normalize = text => String(text || '').toLocaleLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().split(/\s+/).filter(Boolean);
  const phraseMatches = (phrase, textWords) => {
    const phraseWords = normalize(phrase);
    if (!phraseWords.length || phraseWords.length > textWords.length) return false;
    return textWords.some((_, index) => phraseWords.every((word, offset) => textWords[index + offset] === word));
  };
  const textWords = normalize(value);
  if (!textWords.length) return '';
  let bestMatch = null;
  window.aleeCategories.forEach(category => {
    const phrases = [category.label, ...category.keywords];
    phrases.forEach(phrase => {
      const phraseWords = normalize(phrase);
      if (!phraseMatches(phrase, textWords)) return;
      const score = phraseWords.join(' ').length;
      if (!bestMatch || score > bestMatch.score) bestMatch = { id:category.id, score };
    });
  });
  return bestMatch ? bestMatch.id : '';
};
