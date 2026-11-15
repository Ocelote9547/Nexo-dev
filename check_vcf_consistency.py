import re

with open('local_test_data/contacts_272_anonymized.vcf', 'r', encoding='utf-8') as f:
    content = f.read()

cards = content.split('BEGIN:VCARD')
cards = cards[1:]  # Skip first empty

print(f'Total cards: {len(cards)}')

# Find cards with name inconsistencies (N vs FN mismatch)
inconsistencies = []
for i, card in enumerate(cards, 1):
    if 'END:VCARD' not in card:
        continue
    card_content = card.split('END:VCARD')[0]
    
    # Get FN
    fn_match = re.search(r'^FN;?[^:]*:(.+)$', card_content, re.MULTILINE)
    fn = fn_match.group(1).strip() if fn_match else None
    
    # Get N
    n_match = re.search(r'^N;?[^:]*:(.+)$', card_content, re.MULTILINE)
    n_val = n_match.group(1).strip() if n_match else None
    
    if fn and n_val:
        # Parse N parts: family;given;middle;prefix;suffix
        n_parts = n_val.split(';')
        n_family = n_parts[0].strip() if len(n_parts) > 0 else ''
        n_given = n_parts[1].strip() if len(n_parts) > 1 else ''
        
        # FN should match "given family" or "family given"
        fn_normalized = fn.replace('  ', ' ').strip()
        n_full = f"{n_given} {n_family}".strip()
        n_full_rev = f"{n_family} {n_given}".strip()
        
        if fn_normalized != n_full and fn_normalized != n_full_rev:
            inconsistencies.append((i, fn, n_val))

print(f'\nCards with N/FN inconsistency: {len(inconsistencies)}')
for idx, fn, n_val in inconsistencies:
    print(f'  Card {idx}: FN="{fn}", N="{n_val}"')
