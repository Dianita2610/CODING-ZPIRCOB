*&---------------------------------------------------------------------*
*&  Include           ZPIRCOB_UPD_FAC_SEL
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* SELECTION-SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN: BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.
PARAMETERS: p_bukrs TYPE bukrs OBLIGATORY,
            p_fehas TYPE sydatum OBLIGATORY,
            p_hohas TYPE syuzeit OBLIGATORY.
SELECTION-SCREEN SKIP.
PARAMETERS: p_test AS CHECKBOX.
SELECTION-SCREEN: END OF BLOCK b1.


*--------------------------------------------------------------------*
* INITIALIZATION
*--------------------------------------------------------------------*
INITIALIZATION.

  AUTHORITY-CHECK OBJECT 'S_TCODE'
            ID 'TCD' FIELD gc_tcode.

  IF sy-subrc <> 0.
*     Falta autorización para transacción &
    MESSAGE e077(s#) WITH gc_tcode.
  ENDIF.


*----------------------------------------------------------------------
* AT SELECTION-SCREEN
*----------------------------------------------------------------------
AT SELECTION-SCREEN ON p_bukrs.

  SELECT SINGLE FROM t001 FIELDS @abap_true
    WHERE bukrs = @p_bukrs
    INTO @DATA(lv_result).
  IF sy-subrc <> 0.
*   La sociedad & no está prevista
    MESSAGE e165(f5) WITH p_bukrs.
  ENDIF.

  AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
           ID 'BUKRS' FIELD p_bukrs
           ID 'ACTVT' FIELD '03'.

  IF sy-subrc <> 0.
*   Ud. carece de autorización para la sociedad &.
    MESSAGE e460(f5) WITH p_bukrs.
  ENDIF.


AT SELECTION-SCREEN.

  IF NOT p_bukrs IS INITIAL.
    PERFORM val_fecha CHANGING gv_felog gv_holog.
  ENDIF.
