1. Checkout an Athena build with ROOT nightly (currently has RNTuple RC3)
2. Get an ATLAS RAW file
3. Run reco:
```bash
Reco_tf.py \
  --CA="True" \
  --maxEvents=40 \
  --multithreaded="True" \
  --sharedWriter="True" \
  --parallelCompression="False" \
  --inputBSFile="raw.root" \
  --outputDAOD_TLAFile="daod_tla.root" \
  --preExec="flags.Output.StorageTechnology.EventData=\"ROOTRNTUPLE\"";
```
