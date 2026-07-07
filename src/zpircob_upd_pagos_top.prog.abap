*&---------------------------------------------------------------------*
*&  Include           ZPIRCOB_UPD_PAGOS_TOP
*&---------------------------------------------------------------------*
CONSTANTS: gc_tcode TYPE tcode    VALUE 'ZFI_PCPAG'.

TABLES: bkpf.

DATA: gv_felog TYPE zde_fefin_uef,
      gv_holog TYPE zde_hofin_uef.
