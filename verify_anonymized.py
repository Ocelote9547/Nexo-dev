import re

with open('local_test_data/contacts_272_anonymized.vcf', 'r', encoding='utf-8') as f:
    content = f.read()

cards = content.split('BEGIN:VCARD')
cards = cards[1:]

print(f'Total cards: {len(cards)}')

# Count PHOTO properties
photo_count = content.count('PHOTO;')
print(f'PHOTO properties: {photo_count}')

# Find email-only cards
email_only_cards = []
for i, card in enumerate(cards, 1):
    if 'END:VCARD' not in card:
        continue
    card_content = card.split('END:VCARD')[0]
    has_fn = bool(re.search(r'^FN:', card_content, re.MULTILINE))
    has_n = bool(re.search(r'^N:', card_content, re.MULTILINE))
    has_tel = bool(re.search(r'^TEL;', card_content, re.MULTILINE))
    has_email = bool(re.search(r'^EMAIL;', card_content, re.MULTILINE))
    
    if has_email and not has_fn and not has_n and not has_tel:
        email_match = re.search(r'^EMAIL;?[^:]*:(.+)$', card_content, re.MULTILINE)
        email = email_match.group(1).strip() if email_match else 'UNKNOWN'
        email_only_cards.append((i, email))

print(f'Email-only cards: {len(email_only_cards)}')
for idx, email in email_only_cards:
    print(f'  Card {idx}: {email}')

# Count BDAY properties
bday_count = content.count('BDAY:')
print(f'BDAY properties: {bday_count}')
