INSERT INTO product.brand (id, label, description)
    VALUES
        (1, 'Gap', 'The Gap'),
        (2, 'Boss', 'Boss'),
        (3, 'Diesel', 'Diesel'),
        (4, 'Aéropostale',' Aéropostale Inc'),
        (5, 'Levis', 'Levi Strauss & Co'),
        (6, 'Nike', 'Athletic apparel and footwear'),
        (7, 'Adidas', 'Sports and lifestyle brand'),
        (8, 'Zara', 'Fast fashion and contemporary clothing'),
        (9, 'H&M', 'Affordable fashion for all'),
        (10, 'Uniqlo', 'Japanese casual wear'),
        (11, 'Calvin Klein', 'American fashion house'),
        (12, 'Tommy Hilfiger', 'Premium lifestyle brand'),
        (13, 'Polo Ralph Lauren', 'Classic American style'),
        (14, 'Lacoste', 'French clothing company'),
        (15, 'Under Armour', 'Performance apparel'),
        (16, 'Tyrwhitt', 'Charles Tyrwhitt'), -- was 6
        (17, 'Eaton', 'Eaton Tayloring'), -- was 7
        (18, 'Brioni', 'Brioni Tayloring') -- was 8
    ON CONFLICT (id) DO NOTHING; 

