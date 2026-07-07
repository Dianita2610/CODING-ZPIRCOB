*&---------------------------------------------------------------------*
*&  Include           ZPIRCOB_UPD_PAGOS_F01
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Form  VAL_FECHA
*&---------------------------------------------------------------------*
FORM val_fecha CHANGING cv_felog TYPE zde_fefin_uef
                        cv_holog TYPE zde_hofin_uef.

  DATA: lv_femax TYPE sydatum,
        lv_date  TYPE sydatum,
        lv_year  TYPE gjahr.

  SELECT SINGLE FROM zpircob_control FIELDS feuej_cob, houej_cob
    WHERE bukrs = @p_bukrs
    INTO @DATA(ls_control).

  IF sy-subrc = 0 AND NOT ls_control-feuej_cob IS INITIAL.
    lv_year  = ls_control-feuej_cob+0(4).
    lv_year  = lv_year + 1.

    lv_femax = |{ lv_year }{ ls_control-feuej_cob+4(4) } |.
    cv_felog = ls_control-feuej_cob.
    cv_holog = ls_control-houej_cob.
  ELSE.
*   Rescatar fecha inicial de STVARVC
    SELECT SINGLE FROM tvarvc FIELDS low
      WHERE name = 'ZPIRCOB_UPD_FAC_FEMIN'
        AND type = 'P'
        AND numb = '0000'
      INTO @DATA(lv_low).

    IF NOT lv_low IS INITIAL.
      lv_date = lv_low.
    ELSE.
      lv_date = '20000101'.
    ENDIF.

    lv_femax = lv_date + 365.

    cv_felog = lv_date.
    cv_holog = '000001'.
  ENDIF.

* Comparar las fechas
  IF lv_femax < p_fehas.
*   La fecha hasta & excede el año de última ejecución. Maxima fecha &
    MESSAGE e001 WITH p_fehas lv_femax.
    CLEAR: cv_felog, cv_holog.
  ENDIF.

  IF p_fehas < cv_felog.
*   La fecha/hora hasta &1/&2 anterior a última ejecución &3/&4
    MESSAGE e007 WITH p_fehas p_hohas cv_felog cv_holog.
    CLEAR: cv_felog, cv_holog.

  ELSEIF p_fehas = cv_felog.
    IF p_hohas <= cv_holog.
*   La fecha/hora hasta &1/&2 anterior a última ejecución &3/&4
    MESSAGE e007 WITH p_fehas p_hohas cv_felog cv_holog.
      CLEAR: cv_felog, cv_holog.
    ENDIF.
  ENDIF.

ENDFORM.
