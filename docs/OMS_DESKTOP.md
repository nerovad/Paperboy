# OMS Desktop References

## Resume prompt

Resume the OMS desktop-reference investigation in `/mnt/q`. Search only
`.bat` files recursively, excluding directories named `archive` or
`archived` (case-insensitive). Inspect file contents for the exact text
`Desktop`. Report each matching file, line number, and complete matching
statement. Do not modify files under `/mnt/q`.

## Operation results

The non-archive `.bat` files were searched for the exact, case-sensitive text
`Desktop`. Matches were found in 12 files.

```text
/mnt/q/P2M_RE1484_TaxCollector/P2M_RE1484_TaxCollector_P2M_RE1484_TaxCollector_1Perf_Color_DS.bat:20
MOVE ????????-??????-P2M_RE1484_TaxCollector_1Perf.PDF C:\Users\gsa-p2m\Desktop\Tax_1Perf_DS

/mnt/q/P2M_RE1484_TaxCollector/P2M_RE1484_TaxCollector_P2M_RE1484_TaxCollector_2Perf_DS_D9125.bat:20
MOVE ????????-??????-P2M_RE1484_TaxCollector_2Perf.PDF C:\Users\gsa-p2m\Desktop\B9125_TAX_2PERF_DS

/mnt/q/P2M_RE1484_TaxCollector/P2M_RE1484_TaxCollector_P2M_RE1484_TaxCollector_2Perf_DS_D9125.bat:24
MOVE "Mail Sort Summary_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_RE1484_TaxCollector/P2M_RE1484_TaxCollector_P2M_RE1484_TaxCollector_2Perf_DS_D9125.bat:28
MOVE "CASS Summary(PS Form 3553) and NCOALink Processing Summary Report_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_REXXXX_DuplexColor/P2M_REXXXX_DuplexColor.bat:20
MOVE ????????-??????-P2M_PW_REXXXX_DuplexColor.PDF C:\Users\gsa-p2m\Desktop\DuplexColor

/mnt/q/P2M_RE1028_VC_Water/P2M_RE1484_VCWater_0824.bat:20
MOVE ????????-??????-P2M_RE1484_VCWater_0824.PDF C:\Users\gsa-p2m\Desktop\VC_Water

/mnt/q/P2M_RE1484_TaxCollector/P2M_RE1484_TaxCollector_P2M_RE1484_TaxCollector_2Perf_Color.bat:20
MOVE ????????-??????-P2M_RE1484_TaxCollector_2Perf.PDF C:\Users\gsa-p2m\Desktop\Tax_2Perf_DS

/mnt/q/P2M_RE1484_TaxCollector/P2M_RE1484_TaxCollector_P2M_RE1484_TaxCollector_1Perf_Color_SS.bat:20
MOVE ????????-??????-P2M_RE1484_TaxCollector_1Perf.PDF C:\Users\gsa-p2m\Desktop\Tax_1Perf_SS

/mnt/q/P2M_RE1028_DailyLetter/P2M_RE1028_DailyLetterDuplex_B9125 .bat:20
MOVE ????????-??????-P2M_PW_RE1028_DailyLetter.PDF C:\Users\gsa-p2m\Desktop\B9125_DailyLetterDuplex

/mnt/q/P2M_RE1028_DailyLetter/P2M_RE1028_DailyLetterDuplex_B9125 .bat:24
MOVE "Mail Sort Summary_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_RE1028_DailyLetter/P2M_RE1028_DailyLetterDuplex_B9125 .bat:28
MOVE "CASS Summary Report_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_RE1028_DailyLetter/P2M_RE1028_DailyLetter_B9125.bat:20
MOVE ????????-??????-P2M_PW_RE1028_DailyLetter.PDF C:\Users\gsa-p2m\Desktop\B9125_DailyLetter

/mnt/q/P2M_RE1028_DailyLetter/P2M_RE1028_DailyLetter_B9125.bat:24
MOVE "Mail Sort Summary_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_RE1028_DailyLetter/P2M_RE1028_DailyLetter_B9125.bat:28
MOVE "CASS Summary Report_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/IDCARDS/VCHCP_IDCARD_NEWMEMBERPACKET.bat:16
MOVE C:\HotFolder\Outputs\IDCARDS\VCHCP_IDCARD_NEWMEMBERPACKET.PDF C:\Users\gsa-p2m\Desktop\ID_CARDS

/mnt/q/P2M_RE1028_Letter_1Perf/P2M_RE1028_Letter_1Perf_B9125.bat:20
MOVE ????????-??????-P2M_PW_RE1028_Letter_1Perf.PDF C:\Users\gsa-p2m\Desktop\B9125_Daily1Perf

/mnt/q/P2M_RE1028_Letter_1Perf/P2M_RE1028_Letter_1Perf_B9125.bat:24
MOVE "Mail Sort Summary_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_RE1028_Letter_1Perf/P2M_RE1028_Letter_1Perf_B9125.bat:28
MOVE "CASS Summary(PS Form 3553) and NCOALink Processing Summary Report_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_RE1005_Assessor/P2M_RE1005_Assessor_B9125.bat:20
MOVE ????????-??????-P2M_PW_RE1005_ASSESSOR.PDF C:\Users\gsa-p2m\Desktop\B9125_DailyLetterDuplex

/mnt/q/P2M_RE1005_Assessor/P2M_RE1005_Assessor_B9125.bat:24
MOVE "Mail Sort Summary_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/P2M_RE1005_Assessor/P2M_RE1005_Assessor_B9125.bat:28
MOVE "CASS Summary Report_????????.PDF" C:\Users\gsa-p2m\Desktop\B9125_USPS

/mnt/q/IDCARDS/VCHCP_IDCARD_REPLACEMENT.bat:14
MOVE C:\HotFolder\Outputs\IDCARDS\VCHCP_IDCARD_REPLACEMENT.pdf C:\Users\gsa-p2m\Desktop\ID_CARDS
```
