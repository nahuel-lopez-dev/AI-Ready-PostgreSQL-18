

INSERT INTO product.category (id, label, description)
    VALUES
        (1, 'Pants', 'long trousers'),
        (2, 'Shirts', 'long sleeve and short sleeve shirts'),
        (3, 'T-Shirts', 'long sleev and short sleeve T-shirts'),
        (4, 'Polos', 'long sleeve and short sleeve polos'),
        (3, 'Blouses', 'long sleeve and short sleeve shirts for women'),
        (4, 'Footwear', 'Dress shoes, sneakers, and sport shoes'),
        (5, 'Accessories', 'Belts, watches, sunglasses, and other accessories'),
        (6, 'Outerwear', 'Jackets, coats, and outdoor clothing'),
        (7, 'Sportswear', 'Athletic and casual sports clothing'),
        (8, 'Dresses', 'Formal and casual dresses for women'),
        (9, 'Swimwear', 'Swimming and beach attire'),
        (10, 'Jackets', 'Suit coats, leather jackets, sports coats'), -- was 5
        (11, 'Coats', 'Trench coats, duffle coats') -- was 6
    ON CONFLICT (id) DO NOTHING;
    