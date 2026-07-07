*&---------------------------------------------------------------------*
*&  Include           ZPIRCOB_UPD_PAGOS_CLA
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION.

  PUBLIC SECTION.

    TYPES: BEGIN OF gty_data,
             bukrs   TYPE bukrs,
             perio_c TYPE zde_perio_c,
             perio_f TYPE zde_perio_f,
             gjahr   TYPE gjahr,
             monat   TYPE monat,
             mntco   TYPE zde_mntco,
             waers   TYPE waers,
           END OF gty_data.

    TYPES: BEGIN OF gty_bkpf,
             bukrs   TYPE bukrs,
             belnr   TYPE belnr_d,
             gjahr   TYPE gjahr,
             monat   TYPE monat,
             blart   TYPE blart,
             cpudt   TYPE cpudt,
             cputm   TYPE cputm,
             waers   TYPE waers,
             perio_c TYPE zde_perio_c,
             perio_f TYPE zde_perio_f,
           END OF gty_bkpf,

           gtt_bkpf TYPE STANDARD TABLE OF gty_bkpf.

    TYPES: gtt_data  TYPE STANDARD TABLE OF gty_data,
           gtt_pendi TYPE STANDARD TABLE OF zpircob_pend.

    DATA: gt_data TYPE gtt_data,
          gt_bkpf TYPE gtt_bkpf.


    METHODS:
      constructor,

      get_data IMPORTING iv_bukrs TYPE bukrs,

      upd_logtab,

      show_data.


  PRIVATE SECTION.

    METHODS:
      upd_control IMPORTING iv_bukrs     TYPE bukrs
                            iv_feuej_cob TYPE zde_feuej_cob
                            iv_houej_cob TYPE zde_houej_cob,

      get_old_documents CHANGING ct_bkpf TYPE gtt_bkpf,

      reg_pendi IMPORTING it_pendi TYPE gtt_pendi,

      upd_tabla_pag.


ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD constructor.

    CLEAR: gt_data, gt_bkpf.

  ENDMETHOD.

  METHOD get_data.

    DATA: lt_pendi   TYPE gtt_pendi.

    DATA: lv_perio_c TYPE zde_perio_c,
          lv_perio_f TYPE zde_perio_f.

*   Rescatar documentos que estaban pendientes en la última ejecución
    get_old_documents( CHANGING ct_bkpf = gt_bkpf ).

*   Con los registros encontrados se buscan los doc. compensados
    CHECK NOT gt_bkpf[] IS INITIAL.

    SELECT FROM bsad FIELDS bukrs, belnr, gjahr, waers
      FOR ALL ENTRIES IN @gt_bkpf
      WHERE bukrs = @gt_bkpf-bukrs
        AND belnr = @gt_bkpf-belnr
        AND gjahr = @gt_bkpf-gjahr
      INTO TABLE @DATA(lt_bsad).

    SORT lt_bsad BY bukrs belnr gjahr.

*   Determinar los documentos que no estan en la BSAD
    LOOP AT gt_bkpf ASSIGNING FIELD-SYMBOL(<ls_bkpf>).
      READ TABLE lt_bsad ASSIGNING FIELD-SYMBOL(<ls_bsad>)
        WITH KEY bukrs = <ls_bkpf>-bukrs
                 belnr = <ls_bkpf>-belnr
                 gjahr = <ls_bkpf>-gjahr BINARY SEARCH.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO lt_pendi ASSIGNING FIELD-SYMBOL(<ls_pendi>).
        MOVE-CORRESPONDING <ls_bkpf> TO <ls_pendi>.
        DELETE gt_bkpf.
      ENDIF.
    ENDLOOP.

*   Registrar los documentos no encontrados en tabla pagos pendientes compensar
    IF NOT lt_pendi[] IS INITIAL.
      me->reg_pendi( EXPORTING it_pendi = lt_pendi ).
    ENDIF.

    CHECK NOT gt_bkpf[] IS INITIAL.
    SORT gt_bkpf BY bukrs belnr gjahr.

*   Buscar documentos compensados
    SELECT FROM bsad
      FIELDS bukrs, augbl, auggj, blart, monat,
             belnr, gjahr, budat, shkzg, dmbtr, waers
      FOR ALL ENTRIES IN @gt_bkpf
      WHERE bukrs = @gt_bkpf-bukrs
        AND augbl = @gt_bkpf-belnr
        AND auggj = @gt_bkpf-gjahr
        AND blart <> 'DZ'
      INTO TABLE @DATA(lt_facturas_compensadas).

    SORT lt_facturas_compensadas BY bukrs augbl auggj.

***
    LOOP AT gt_bkpf ASSIGNING <ls_bkpf>.
**
      LOOP AT lt_facturas_compensadas ASSIGNING FIELD-SYMBOL(<ls_fac>)
        WHERE bukrs = <ls_bkpf>-bukrs
          AND augbl = <ls_bkpf>-belnr
          AND auggj = <ls_bkpf>-gjahr.

        lv_perio_c = |{ <ls_bkpf>-gjahr }{ <ls_bkpf>-monat }|.
        lv_perio_f = |{ <ls_fac>-gjahr }{ <ls_fac>-monat }|.

*       Se busca si ya existe un registro para el período
        READ TABLE gt_data ASSIGNING FIELD-SYMBOL(<ls_data>)
          WITH KEY bukrs   = <ls_bkpf>-bukrs
                   perio_c = lv_perio_c
                   perio_f = lv_perio_f.
        IF sy-subrc = 0.
*         Si existe registro, acumula los importes
          IF <ls_fac>-shkzg = 'S'.
            <ls_data>-mntco = <ls_data>-mntco + <ls_fac>-dmbtr.
          ELSE.
            <ls_data>-mntco = <ls_data>-mntco - <ls_fac>-dmbtr.
          ENDIF.
        ELSE.
*         Si no existe, agrega un registro nuevo
          APPEND INITIAL LINE TO gt_data ASSIGNING <ls_data>.
          <ls_data>-bukrs   = <ls_fac>-bukrs.
          <ls_data>-perio_c = lv_perio_c.
          <ls_data>-perio_f = lv_perio_f.
          <ls_data>-gjahr   = <ls_bkpf>-gjahr. " <ls_fac>-gjahr.
          <ls_data>-monat   = <ls_bkpf>-monat. "<ls_fac>-monat.
          <ls_data>-waers   = <ls_bkpf>-waers.

          IF <ls_fac>-shkzg = 'S'.
            <ls_data>-mntco = <ls_fac>-dmbtr.
          ELSE.
            <ls_data>-mntco = 0 - <ls_fac>-dmbtr.
          ENDIF.
        ENDIF.

*       Actualizar campos para el respaldo
        <ls_bkpf>-perio_c = lv_perio_c.
        <ls_bkpf>-perio_f = lv_perio_f.

      ENDLOOP.

      IF sy-subrc <> 0.
        DELETE gt_bkpf.
      ENDIF.
**
    ENDLOOP.
***

  ENDMETHOD.

  METHOD upd_logtab.

    TYPES: BEGIN OF lty_key,
             bukrs   TYPE bukrs,
             perio_c TYPE zde_perio_c,
             perio_f TYPE zde_perio_f,
           END OF lty_key,

           ltt_key TYPE STANDARD TABLE OF lty_key.

    DATA: lt_key           TYPE ltt_key,
          lt_zpircob_sum_c TYPE STANDARD TABLE OF zpircob_sum_c.


    IF gt_data[] IS INITIAL.
*     No se encontraron datos para tratar
      MESSAGE i004.
      RETURN.
    ENDIF.

*   Crear TI con llave
    LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      APPEND INITIAL LINE TO lt_key ASSIGNING FIELD-SYMBOL(<ls_key>).
      <ls_key>-bukrs   = <ls_data>-bukrs.
      <ls_key>-perio_c = <ls_data>-perio_c.
      <ls_key>-perio_f = <ls_data>-perio_f.
    ENDLOOP.

    CHECK NOT lt_key[] IS INITIAL.
    SORT lt_key BY bukrs perio_c perio_f.

    SELECT FROM zpircob_sum_c FIELDS mandt, bukrs, perio_c, perio_f, mntco, waers
      FOR ALL ENTRIES IN @lt_key
      WHERE bukrs   = @lt_key-bukrs
        AND perio_c = @lt_key-perio_c
        AND perio_f = @lt_key-perio_f
      INTO TABLE @lt_zpircob_sum_c.

    SORT lt_zpircob_sum_c BY mandt bukrs perio_c perio_f.

*   Preparar tabla de actualización
    LOOP AT gt_data ASSIGNING <ls_data>.
      READ TABLE lt_zpircob_sum_c ASSIGNING FIELD-SYMBOL(<ls_sum>)
        WITH KEY mandt   = sy-mandt
                 bukrs   = <ls_data>-bukrs
                 perio_c = <ls_data>-perio_c
                 perio_f = <ls_data>-perio_f BINARY SEARCH.
      IF sy-subrc = 0.
        <ls_sum>-mntco = <ls_sum>-mntco + <ls_data>-mntco.
      ELSE.
        APPEND INITIAL LINE TO lt_zpircob_sum_c ASSIGNING <ls_sum>.
        <ls_sum>-mandt   = sy-mandt.
        <ls_sum>-bukrs   = <ls_data>-bukrs.
        <ls_sum>-perio_c = <ls_data>-perio_c.
        <ls_sum>-perio_f = <ls_data>-perio_f.
        <ls_sum>-mntco   = <ls_data>-mntco.
        <ls_sum>-waers   = <ls_data>-waers.
      ENDIF.

    ENDLOOP.

    MODIFY zpircob_sum_c FROM TABLE lt_zpircob_sum_c.

    IF sy-subrc = 0.
*     Actualizar tabla de documentos tratados
      me->upd_tabla_pag( ).

      COMMIT WORK.

    ELSE.
      ROLLBACK WORK.
*     Error al actualizar tabla sumatoria documentos de ventas período
      MESSAGE i003.
    ENDIF.

  ENDMETHOD.

  METHOD show_data.

    IF NOT gt_data[] IS INITIAL.
      cl_demo_output=>display( gt_data ).
    ELSE.
*     No se encontraron datos para tratar
      MESSAGE i004.
    ENDIF.

  ENDMETHOD.


  METHOD upd_control.

    DATA: ls_control TYPE zpircob_control.

    CHECK p_test = abap_false.

    SELECT SINGLE FROM zpircob_control FIELDS *
      WHERE bukrs = @iv_bukrs
      INTO @ls_control.

    IF sy-subrc <> 0.
      CLEAR: ls_control.
      ls_control-mandt      = sy-mandt.
      ls_control-bukrs      = iv_bukrs.
      ls_control-feuej_cob  = iv_feuej_cob.
      ls_control-houej_cob  = iv_houej_cob.
    ELSE.
      ls_control-feuej_cob  = iv_feuej_cob.
      ls_control-houej_cob  = iv_houej_cob.
    ENDIF.
    ls_control-erdat      = sy-datum.
    ls_control-erzet      = sy-uzeit.
    ls_control-ernam      = sy-uname.

    MODIFY zpircob_control FROM ls_control.

  ENDMETHOD.

  METHOD get_old_documents.
*<-> ct_bkpf TYPE gtt_bkpf

*   Rescata los registros de la tabla de pagos pendientes compensar
    SELECT FROM zpircob_pend FIELDS bukrs, belnr, gjahr
      WHERE stblg = ' '
      INTO TABLE @DATA(lt_pend).

    IF NOT lt_pend[] IS INITIAL.
*     Rescata el estado actual de los documentos: Si están anulados no los considera
      SELECT FROM bkpf
        FIELDS bukrs, belnr, gjahr, monat, blart, stblg, cpudt, cputm, waers
        FOR ALL ENTRIES IN @lt_pend
        WHERE bukrs = @lt_pend-bukrs
          AND belnr = @lt_pend-belnr
          AND gjahr = @lt_pend-gjahr
          AND stblg = ' '
        INTO TABLE @DATA(lt_bkpf).

*     Agrega los docuentos no anulados a la tabla ct_bkpf
      LOOP AT lt_bkpf ASSIGNING FIELD-SYMBOL(<ls_bkpf>).
        APPEND INITIAL LINE TO ct_bkpf ASSIGNING FIELD-SYMBOL(<ls_cbkpf>).
        MOVE-CORRESPONDING <ls_bkpf> TO <ls_cbkpf>.
      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD reg_pendi.
*-> it_pendi TYPE gtt_pendi
**add comment
    DELETE FROM zpircob_pend WHERE stblg = ' '."#EC CI_NOFIELD
**add comment
    INSERT zpircob_pend FROM TABLE it_pendi.
    COMMIT WORK.

  ENDMETHOD.

  METHOD upd_tabla_pag.

    TYPES: lty_resp_pag TYPE zpircob_resp_pag,
           ltt_resp_pag TYPE STANDARD TABLE OF lty_resp_pag.

    DATA: lt_resp_pag TYPE ltt_resp_pag.

    LOOP AT gt_bkpf ASSIGNING FIELD-SYMBOL(<ls_bkpf>).
      APPEND INITIAL LINE TO lt_resp_pag ASSIGNING FIELD-SYMBOL(<ls_resp_pag>).
      <ls_resp_pag>-bukrs   = <ls_bkpf>-bukrs.
      <ls_resp_pag>-belnr   = <ls_bkpf>-belnr.
      <ls_resp_pag>-gjahr   = <ls_bkpf>-gjahr.
      <ls_resp_pag>-monat   = <ls_bkpf>-monat.
      <ls_resp_pag>-erdat   = sy-datum.
      <ls_resp_pag>-erzet   = sy-uzeit.
      <ls_resp_pag>-ernam   = sy-uname.
      <ls_resp_pag>-perio_c = <ls_bkpf>-perio_c.
      <ls_resp_pag>-perio_f = <ls_bkpf>-perio_f.
    ENDLOOP.

    MODIFY zpircob_resp_pag FROM TABLE lt_resp_pag.

  ENDMETHOD.

ENDCLASS.
