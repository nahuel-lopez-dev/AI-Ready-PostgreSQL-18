INSERT INTO product_variant (product_id, attributes)
    VALUES
        -- dress shirt Gap variants
        (1, '{"color": "white", "size": "S", "collar": "spread", "fit": "slim"}'),
        (1, '{"color": "white", "size": "M", "collar": "spread", "fit": "slim"}'),
        (1, '{"color": "white", "size": "L", "collar": "spread", "fit": "slim"}'),
        (1, '{"color": "blue", "size": "S", "collar": "spread", "fit": "classic"}'),
        (1, '{"color": "blue", "size": "M", "collar": "spread", "fit": "classic"}'),
        (1, '{"color": "blue", "size": "L", "collar": "spread", "fit": "classic"}'),
       
        -- dress shirt Boss variants
        (2, '{"color": "white", "size": "S", "collar": "classic", "fit": "slim"}'),
        (2, '{"color": "white", "size": "M", "collar": "classic", "fit": "slim"}'),
        (2, '{"color": "white", "size": "L", "collar": "classic", "fit": "slim"}'),
        (2, '{"color": "blue", "size": "S", "collar": "contrast", "fit": "classic"}'),
        (2, '{"color": "blue", "size": "M", "collar": "contrast", "fit": "classic"}'),
        (2, '{"color": "blue", "size": "L", "collar": "contrast", "fit": "classic"}'),

        --- dress shirt Eaton variants
        (3, '{"color": "white", "size": "S", "collar": "pinned", "fit": "slim"}'),
        (3, '{"color": "white", "size": "M", "collar": "pinned", "fit": "slim"}'),
        (3, '{"color": "white", "size": "L", "collar": "pinned", "fit": "slim"}'),
        (3, '{"color": "blue", "size": "S", "collar": "club", "fit": "classic"}'),
        (3, '{"color": "blue", "size": "M", "collar": "club", "fit": "classic"}'),
        (3, '{"color": "blue", "size": "L", "collar": "club", "fit": "classic"}'),

        --- Oxford shirt Gap variants
        (4, '{"color": "white", "size": "S", "collar": "button down", "fit": "slim"}'),
        (4, '{"color": "white", "size": "M", "collar": "button down", "fit": "slim"}'),
        (4, '{"color": "white", "size": "L", "collar": "button down", "fit": "slim"}'),
        (4, '{"color": "blue", "size": "S", "collar": "button down", "fit": "slim"}'),
        (4, '{"color": "blue", "size": "M", "collar": "button down", "fit": "slim"}'),
        (4, '{"color": "blue", "size": "L", "collar": "button down", "fit": "slim"}'),

        --- Oxford shirt Boss
        (5, '{"color": "white", "size": "S", "collar": "button down", "fit": "classic"}'),
        (5, '{"color": "white", "size": "M", "collar": "button down", "fit": "classic"}'),
        (5, '{"color": "white", "size": "L", "collar": "button down", "fit": "classic"}'),
        (5, '{"color": "blue", "size": "S", "collar": "button down", "fit": "classic"}'),
        (5, '{"color": "blue", "size": "M", "collar": "button down", "fit": "classic"}'),
        (5, '{"color": "blue", "size": "L", "collar": "button down", "fit": "classic"}'),

        --- Gap T-shirt variants
        (6, '{"color": "white", "size": "S",  "fit": "classic"}'),
        (6, '{"color": "white", "size": "M",  "fit": "classic"}'),
        (6, '{"color": "white", "size": "L",  "fit": "classic"}'),
        (6, '{"color": "white", "size": "XL",  "fit": "classic"}'),
        (6, '{"color": "yellow", "size": "S",  "fit": "classic"}'),
        (6, '{"color": "yellow", "size": "M",  "fit": "classic"}'),
        (6, '{"color": "yellow", "size": "L",  "fit": "classic"}'),
        (6, '{"color": "yellow", "size": "XL",  "fit": "classic"}'),

        --- Diesel T-Shirt variants
        (7, '{"color": "green", "size": "S",  "fit": "relaxed"}'),
        (7, '{"color": "green", "size": "M",  "fit": "relaxed"}'),
        (7, '{"color": "green", "size": "L",  "fit": "relaxed"}'),
        (7, '{"color": "green", "size": "XL",  "fit": "relaxed"}'),
        (7, '{"color": "red", "size": "S",  "fit": "relaxed"}'),
        (7, '{"color": "red", "size": "M",  "fit": "relaxed"}'),
        (7, '{"color": "red", "size": "L",  "fit": "relaxed"}'),
        (7, '{"color": "red", "size": "XL",  "fit": "relaxed"}'),

        --- Levis Jeans variants
        (8, '{"style": "501", "color": "blue", "size": "28/32", "prep": "stonewash"}'),
        (8, '{"style": "501", "color": "blue", "size": "30/34", "prep": "stonewash"}'),
        (8, '{"style": "501", "color": "blue", "size": "30/36", "prep": "stonewash"}'),
        (8, '{"style": "501", "color": "blue", "size": "32/36", "prep": "stonewash"}'),
        (8, '{"style": "501", "color": "blue", "size": "34/36", "prep": "stonewash"}'),

        --- Men's leather Jacket by Boss variants
        (9, '{"color": "brown", "size": "S",  "collar": "stand collar"}'),
        (9, '{"color": "brown", "size": "M",  "collar": "stand collar"}'),
        (9, '{"color": "brown", "size": "L",  "collar": "stand collar"}'),
        --- Men's leather Jacket by Aeropostale variants
        (10, '{"color": "black", "size": "S",  "collar": "mandarin collar"}'),
        (10, '{"color": "black", "size": "M",  "collar": "mandarin collar"}'),
        (10, '{"color": "black", "size": "L",  "collar": "mandarin collar"}'), 

        --- Men's Chinos by Gap variants
        (11, '{"color": "beige", "size": "30W",  "fit": "slim"}'),              
        (11, '{"color": "beige", "size": "32W",  "fit": "slim"}'),  
        (11, '{"color": "beige", "size": "34W",  "fit": "slim"}'), 
        (11, '{"color": "blue", "size": "30W",  "fit": "slim"}'),              
        (11, '{"color": "blue", "size": "32W",  "fit": "slim"}'),  
        (11, '{"color": "blue", "size": "34W",  "fit": "slim"}'),     

        --- Men's Chinos by Boss variants
        (11, '{"color": "beige", "size": "30W",  "fit": "classic"}'),              
        (11, '{"color": "beige", "size": "32W",  "fit": "classic"}'),  
        (11, '{"color": "beige", "size": "34W",  "fit": "classic"}'), 
        (11, '{"color": "blue", "size": "30W",  "fit": "classic"}'),              
        (11, '{"color": "blue", "size": "32W",  "fit": "classic"}'),  
        (11, '{"color": "blue", "size": "34W",  "fit": "classic"}'),   

        --- Sports coat by Boss    
        (12, '{"color": "brown", "size": "44",  "fit": "regular"}'),
        (12, '{"color": "brown", "size": "46",  "fit": "regular"}'),
        (12, '{"color": "brown", "size": "48",  "fit": "regular"}'),
        (12, '{"color": "blue", "size": "44",  "fit": "tall"}'),
        (12, '{"color": "blue", "size": "46",  "fit": "tall"}'),
        (12, '{"color": "blue", "size": "48",  "fit": "tall"}'),

        --- Suit coat by Boss variants
        (13, '{"color": "brown", "size": "44",  "fit": "regular", "fabric": "linen"}'),
        (13, '{"color": "brown", "size": "46",  "fit": "regular", "fabric": "linen"}'),
        (13, '{"color": "brown", "size": "48",  "fit": "regular", "fabric": "linen"}'),
        (13, '{"color": "blue", "size": "44",  "fit": "tall", "fabric": "wool"}'),
        (13, '{"color": "blue", "size": "46",  "fit": "tall", "fabric": "wool" }'),
        (13, '{"color": "blue", "size": "48",  "fit": "tall", "fabric": "wool"}'),

        --- Suit coat by Brioni variants
        (14, '{"color": "light grey", "size": "44",  "fit": "tailored", "fabric": "wool"}'),
        (14, '{"color": "light grey", "size": "46",  "fit": "tailored", "fabric": "wool"}'),
        (14, '{"color": "light grey", "size": "48",  "fit": "tailored", "fabric": "wool"}'),
        (14, '{"color": "navy blue", "size": "44",  "fit": "tailored", "fabric": "wool"}'),
        (14, '{"color": "navy blue", "size": "46",  "fit": "tailored", "fabric": "wool" }'),
        (14, '{"color": "navy blue", "size": "48",  "fit": "tailored", "fabric": "wool"}'),

        --- Trench coat variants
        (15, '{"color": "light grey", "size": "S",  "waterproof": "yes", "fabric": "nylon"}'),
        (15, '{"color": "light grey", "size": "M",  "waterproof": "yes", "fabric": "nylon"}'),
        (15, '{"color": "light grey", "size": "L",  "waterproof": "yes", "fabric": "nylon"}'),

        -- Polo Shirt by The Gap variants
        (16, '{"color": "blue", "size": "S",  "fabric": "cotton", "nit": "pique"}'),
        (16, '{"color": "blue", "size": "M",  "fabric": "cotton", "nit": "pique"}'),
        (16, '{"color": "blue", "size": "L",  "fabric": "cotton", "nit": "pique"}'),
        (16, '{"color": "green", "size": "S",  "fabric": "cotton", "nit": "pique"}'),
        (16, '{"color": "green", "size": "M",  "fabric": "cotton", "nit": "pique"}'),
        (16, '{"color": "green", "size": "L",  "fabric": "cotton", "nit": "pique"}'),

        -- Polo Shirt by Boss variants
        (17, '{"color": "red", "size": "S",  "fabric": "cotton", "nit": "pique"}'),
        (17, '{"color": "red", "size": "M",  "fabric": "cotton", "nit": "pique"}'),
        (17, '{"color": "red", "size": "L",  "fabric": "cotton", "nit": "pique"}'),
        (17, '{"color": "blue", "size": "S",  "fabric": "cotton", "nit": "pique"}'),
        (17, '{"color": "blue", "size": "M",  "fabric": "cotton", "nit": "pique"}'),
        (17, '{"color": "blue", "size": "L",  "fabric": "cotton", "nit": "pique"}'),

        -- Calvin Klein Shirt variants
        (18, '{"color": "white", "size": "M", "collar": "spread", "fit": "slim"}'),
        (18, '{"color": "light blue", "size": "L", "collar": "spread", "fit": "slim"}'),
        (18, '{"color": "white", "size": "XL", "collar": "spread", "fit": "regular"}'),
        
        -- Zara Silk Blouse variants
        (19, '{"color": "ivory", "size": "S", "material": "silk", "style": "professional"}'),
        (19, '{"color": "navy", "size": "M", "material": "silk", "style": "professional"}'),
        (19, '{"color": "black", "size": "L", "material": "silk", "style": "professional"}'),
        
        -- Tommy Hilfiger Polo variants
        (20, '{"color": "navy", "size": "M", "style": "classic polo", "logo": "flag"}'),
        (20, '{"color": "white", "size": "L", "style": "classic polo", "logo": "flag"}'),
        (20, '{"color": "red", "size": "XL", "style": "classic polo", "logo": "flag"}'),
        
        -- Ralph Lauren Chinos variants
        (21, '{"color": "khaki", "size": "32x32", "fit": "classic", "material": "cotton twill"}'),
        (21, '{"color": "navy", "size": "34x32", "fit": "classic", "material": "cotton twill"}'),
        (21, '{"color": "olive", "size": "36x32", "fit": "classic", "material": "cotton twill"}'),
        
        -- Zara Midi Dress variants
        (22, '{"color": "black", "size": "S", "length": "midi", "style": "A-line"}'),
        (22, '{"color": "navy", "size": "M", "length": "midi", "style": "A-line"}'),
        (22, '{"color": "burgundy", "size": "L", "length": "midi", "style": "A-line"}'),
        
        -- Nike Athletic T-Shirt variants
        (23, '{"color": "black", "size": "M", "technology": "Dri-FIT", "fit": "athletic"}'),
        (23, '{"color": "grey", "size": "L", "technology": "Dri-FIT", "fit": "athletic"}'),
        (23, '{"color": "blue", "size": "XL", "technology": "Dri-FIT", "fit": "athletic"}'),
        
        -- Adidas Track Pants variants
        (24, '{"color": "black", "size": "M", "stripe": "white", "style": "classic"}'),
        (24, '{"color": "navy", "size": "L", "stripe": "white", "style": "classic"}'),
        (24, '{"color": "grey", "size": "XL", "stripe": "black", "style": "classic"}'),
        
        -- Under Armour Sports Bra variants
        (25, '{"color": "black", "size": "S", "support": "high", "style": "racerback"}'),
        (25, '{"color": "pink", "size": "M", "support": "high", "style": "racerback"}'),
        (25, '{"color": "grey", "size": "L", "support": "high", "style": "racerback"}'),
        
        -- Uniqlo Down Jacket variants
        (26, '{"color": "black", "size": "M", "fill": "down", "weight": "ultra-light"}'),
        (26, '{"color": "navy", "size": "L", "fill": "down", "weight": "ultra-light"}'),
        (26, '{"color": "grey", "size": "XL", "fill": "down", "weight": "ultra-light"}'),
        
        -- Lacoste Windbreaker variants
        (27, '{"color": "navy", "size": "M", "style": "windbreaker", "logo": "crocodile"}'),
        (27, '{"color": "white", "size": "L", "style": "windbreaker", "logo": "crocodile"}'),
        (27, '{"color": "green", "size": "XL", "style": "windbreaker", "logo": "crocodile"}'),
        
        -- Nike Running Shoes variants
        (28, '{"color": "black", "size": "9", "type": "running", "technology": "Air Max"}'),
        (28, '{"color": "white", "size": "10", "type": "running", "technology": "Air Max"}'),
        (28, '{"color": "blue", "size": "11", "type": "running", "technology": "Air Max"}'),
        
        -- Adidas Lifestyle Sneakers variants
        (29, '{"color": "white", "size": "9", "style": "lifestyle", "stripes": "black"}'),
        (29, '{"color": "black", "size": "10", "style": "lifestyle", "stripes": "white"}'),
        (29, '{"color": "grey", "size": "11", "style": "lifestyle", "stripes": "navy"}'),
        
        -- Calvin Klein Belt variants
        (30, '{"color": "black", "size": "32", "material": "leather", "buckle": "rectangular"}'),
        (30, '{"color": "brown", "size": "34", "material": "leather", "buckle": "rectangular"}'),
        (30, '{"color": "black", "size": "36", "material": "leather", "buckle": "rectangular"}'),
        
        -- Tommy Hilfiger Watch variants
        (31, '{"color": "black", "strap": "leather", "style": "analog", "case": "steel"}'),
        (31, '{"color": "brown", "strap": "leather", "style": "analog", "case": "steel"}'),
        (31, '{"color": "navy", "strap": "leather", "style": "analog", "case": "steel"}');