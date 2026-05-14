# Iris Setup Test Notes - 2026-05-13

Machine: 115
Hardware: i7-6800K, GTX 980 Ti, GTX 1050 Ti, about 62.6GB RAM

## What Worked

- Setup backend detected hardware correctly.
- The two-choice setup flow worked.
- Iris updated her response when corrected.
- The hardware summary was accurate.

## Problems Found

- P1: Iris was on CPU when the user first talked to her.
- P2: Iris suggested the wrong model name: `llama3.2:8b` does not exist.
- P3: GPU identification was poor, including invented names like "A1050".
- P4: Iris did not know what Aider is and described it as image enhancement.
- P5: The setup flow was too confirmation-heavy and would not work uninterrupted.
- P6: Iris fabricated job status and hallucinated probe results.
- P7: Jobs were not actually completing, causing 30+ minute waits.
- P8: Responses were too rambly.
- P9: ANSI escape codes showed as raw text on tty1.

## Architectural Decisions Made

- Option B adopted: silent GPU setup before the UI opens.
- Multi-GPU ranking by VRAM implemented.
- No-GPU fallback path implemented.
- Iris reports what was done; she does not orchestrate firstboot setup.

## Fixes Implemented This Session

- `0ca12ee`: firstboot rewritten for Option B.
- `probe_hardware.sh` updated with multi-GPU `nvidia-smi` detection.
- `setup-prompt.txt` updated to reflect GPU pre-assignment.

## Next Steps

- Check `net/ollama/` and commit it.
- Build a new image from the updated scripts.
- Boot test on 115.
- Validate GPU assignment happens silently before the UI opens.
- Get 115 posting again; hardware issue needs minimum boot config.

# Session 2 Test Notes - 2026-05-14

Machine: 115
Image: prism-net-20260514.raw.gz

## What Worked

- New PRISM image deployed to 115.
- Option B firstboot confirmed working.
- GPU was ready before the UI opened.
- Response time improved to about 1 minute on the GTX 980 Ti, compared with 15-30 minutes in the prior session.

## Problems Found

- Setup mode is still showing in the UI after Option B completes.
- Iris still hallucinates GPU identity.
- Iris invented hardware including "RTX 3080 Ti" and "two 1050 Tis".
- Jobs still are not actually executing.

## Current Conclusion

- Option B works for bringing the GPU up before Iris opens.
- Iris needs exact hardware facts injected at conversation start.
- The next fix should feed `probe_hardware` JSON directly into Iris so she cannot invent GPU facts.

## Next Steps

- Fix Iris GPU identification by feeding exact probe JSON.
- Fix setup mode not clearing after Option B completes.
- Fix the job execution loop.
- Add PKD personality to the personalities doc.
