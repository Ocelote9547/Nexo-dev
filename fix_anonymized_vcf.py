import re

def unfold_vcf_lines(text):
    """Reconstruct folded vCard lines."""
    lines = text.split('\n')
    unfolded = []
    for line in lines:
        line = line.rstrip('\r')
        if line == '':
            continue
        if line.startswith(' ') or line.startswith('\t'):
            # Continuation of previous line
            if unfolded:
                unfolded[-1] = unfolded[-1] + line[1:]
        else:
            unfolded.append(line)
    return unfolded

def parse_vcf_cards(text):
    """Parse VCF content into individual cards."""
    unfolded = unfold_vcf_lines(text)
    cards = []
    current_card = None
    
    for line in unfolded:
        if line == 'BEGIN:VCARD':
            current_card = []
        elif line == 'END:VCARD':
            if current_card is not None:
                cards.append(current_card)
                current_card = None
        elif current_card is not None:
            current_card.append(line)
    
    return cards

def parse_card_properties(card_lines):
    """Parse properties from a card's lines."""
    props = {}
    for line in card_lines:
        colon_idx = line.find(':')
        if colon_idx == -1:
            continue
        left = line[:colon_idx]
        value = line[colon_idx + 1:]
        parts = left.split(';')
        prop_name = parts[0].strip().upper()
        params = {}
        for p in parts[1:]:
            eq_idx = p.find('=')
            if eq_idx != -1:
                params[p[:eq_idx].strip().upper()] = p[eq_idx + 1:]
            else:
                params[p.strip().upper()] = ''
        props[prop_name] = {'params': params, 'value': value, 'full_line': line}
    return props

with open('local_test_data/contacts_272_anonymized.vcf', 'r', encoding='utf-8') as f:
    content = f.read()

cards = parse_vcf_cards(content)
print(f'Total cards parsed: {len(cards)}')

fixed_cards = []
inconsistency_count = 0

for i, card_lines in enumerate(cards, 1):
    props = parse_card_properties(card_lines)
    
    n_prop = props.get('N')
    fn_prop = props.get('FN')
    
    if n_prop and fn_prop:
        n_val = n_prop['value'].strip()
        fn_val = fn_prop['value'].strip()
        
        # Parse N parts: family;given;middle;prefix;suffix
        n_parts = n_val.split(';')
        n_family = n_parts[0].strip() if len(n_parts) > 0 else ''
        n_given = n_parts[1].strip() if len(n_parts) > 1 else ''
        
        # Build expected FN: "given family"
        if n_given and n_family:
            expected_fn = f"{n_given} {n_family}"
        elif n_given:
            expected_fn = n_given
        elif n_family:
            expected_fn = n_family
        else:
            expected_fn = ''
        
        if fn_val != expected_fn:
            inconsistency_count += 1
            # Replace FN line
            old_fn_line = fn_prop['full_line']
            # Use plain text FN (no QP encoding needed for ASCII names)
            new_fn_line = f'FN:{expected_fn}'
            # Replace in the card lines
            for j, line in enumerate(card_lines):
                if line == old_fn_line:
                    card_lines[j] = new_fn_line
                    break

    fixed_cards.append(card_lines)

print(f'Inconsistencies fixed: {inconsistency_count}')

# Reconstruct the VCF
output_lines = []
for card_lines in fixed_cards:
    output_lines.append('BEGIN:VCARD')
    output_lines.extend(card_lines)
    output_lines.append('END:VCARD')

output = '\n'.join(output_lines) + '\n'

with open('local_test_data/contacts_272_anonymized.vcf', 'w', encoding='utf-8') as f:
    f.write(output)

print(f'Fixed VCF written. Total cards: {len(fixed_cards)}')
