#!/usr/bin/env python3
import os, sys
sys.exit(0 if any(
    'document_consumer' in (
        open(f'/proc/{p}/cmdline', 'rb').read().decode('utf-8', 'ignore')
        if os.path.exists(f'/proc/{p}/cmdline') else ''
    )
    for p in os.listdir('/proc') if p.isdigit()
) else 1)
