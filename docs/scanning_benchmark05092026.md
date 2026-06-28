## Library Scanner Benchmark

### Test Environment

* Device: HiBy R4
* RAM: 3GB
* Storage: 256GB microSD Card
* Library Size: 60GB
* Total Audio Files Scanned: 1,287 tracks

---

## Scan Performance Results

| Operation                   |      Time |
| --------------------------- | --------: |
| MediaStore Audio Query      |     180ms |
| Existing Database Load      |       3ms |
| Diff / Entity Build         |       4ms |
| Bulk Upsert (1,287 Songs)   |      43ms |
| Foreground Scan Total       |     315ms |
| Playlist Sync               |       0ms |
| Full MediaStore Scan        | **328ms** |
| MediaStore Non-Audio Query  |      78ms |
| CUE / Log Parsing           |       0ms |
| Sidecar Metadata Processing |      82ms |

---

## Overall Result

* Previous scan duration: **11–12 seconds**
* Current scan duration: **328ms**
* Approximate improvement: **~34× faster**

---

## Notes

The new scanner architecture minimizes filesystem traversal and metadata reparsing via:

* Android MediaStore indexing
* Differential database synchronization
* Batched database upserts
* Reduced metadata parsing overhead
