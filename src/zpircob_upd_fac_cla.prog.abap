*&---------------------------------------------------------------------*
*&  Include           ZPIRCOB_UPD_FAC_CLA
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION.

  PUBLIC SECTION.

    TYPES: BEGIN OF gty_data,
             bukrs TYPE bukrs,
             gjahr TYPE gjahr,
             monat TYPE monat,
             mntfc TYPE zde_mntfc,
             mntnc TYPE zde_mntnc,
             waers TYPE waers,
           END OF gty_data.

    TYPES: BEGIN OF gty_bkpf,
             bukrs TYPE bukrs,
             belnr TYPE belnr_d,
             gjahr TYPE gjahr,
             monat TYPE monat,
             blart TYPE blart,
             cpudt TYPE cpudt,
             cputm TYPE cputm,
             xblnr TYPE xblnr1,
             awtyp TYPE awtyp,
             awkey TYPE awkey,
           END OF gty_bkpf,

           gtt_bkpf TYPE STANDARD TABLE OF gty_bkpf.

    TYPES: gtr_blart TYPE RANGE OF blart,
           gtt_data  TYPE STANDARD TABLE OF gty_data.

    DATA: gr_blart    TYPE gtr_blart,
          gr_blart_fc TYPE gtr_blart,
          gr_blart_nc TYPE gtr_blart.

    DATA: gt_data TYPE gtt_data,
          gt_bkpf TYPE gtt_bkpf.

    DATA: gv_max_date TYPE cpudt,
          gv_max_time TYPE cputm.

    METHODS:
      constructor,

      get_data IMPORTING iv_bukrs TYPE bukrs
                         iv_fehas TYPE sydatum
                         iv_hohas TYPE syuzeit,

      upd_logtab,

      show_data.


  PRIVATE SECTION.

    METHODS:
      fill_ranges EXPORTING er_blart    TYPE gtr_blart
                            er_blart_fc TYPE gtr_blart
                            er_blart_nc TYPE gtr_blart,

      upd_control IMPORTING iv_bukrs     TYPE bukrs
                            iv_fefin_uef TYPE zde_fefin_uef
                            iv_hofin_uef TYPE zde_hofin_uef,

      upd_tabla_fac,

      del_void_sd CHANGING ct_bkpf TYPE gtt_bkpf.

ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD constructor.

    CLEAR: gr_blart, gr_blart_fc, gr_blart_nc.

    CLEAR: gt_data, gt_bkpf.

    CLEAR: gv_max_date, gv_max_time.

  ENDMETHOD.

  METHOD get_data.



    me->fill_ranges( IMPORTING er_blart    = gr_blart
                               er_blart_fc = gr_blart_fc
                               er_blart_nc = gr_blart_nc
    ).

    IF gr_blart_fc[] IS INITIAL OR gr_blart_nc[] IS INITIAL.
*     Clases de documentos no actualizadas en STVARV.
      MESSAGE e005.
      RETURN.
    ENDIF.

*   Rescatar cabecera de documentos de facturación
    SELECT FROM bkpf FIELDS bukrs, belnr, gjahr, monat, blart, cpudt, cputm,
                            xblnr, awtyp, awkey
      WHERE bukrs  = @iv_bukrs
        AND blart IN @gr_blart
        AND cpudt BETWEEN @gv_felog AND @iv_fehas
        AND stblg = ' '
***     AND xblnr <> '0000000000000000'
    INTO TABLE @gt_bkpf.

*   Si no hay datos, actualiza tabla de control con los parámetros actuales
    IF gt_bkpf[] IS INITIAL.
      me->upd_control( EXPORTING iv_bukrs     = iv_bukrs
                                 iv_fefin_uef = iv_fehas
                                 iv_hofin_uef = iv_hohas
                     ).
      RETURN.
    ENDIF.

*   Detectar registros SD anulados
    del_void_sd( CHANGING ct_bkpf = gt_bkpf ).

*
    SORT gt_bkpf BY bukrs
                    cpudt DESCENDING
                    cputm DESCENDING.

*   Controla las horas
    DELETE gt_bkpf WHERE cpudt = gv_felog AND cputm <= gv_holog.
    DELETE gt_bkpf WHERE cpudt = iv_fehas AND cputm >= iv_hohas.

    IF gt_bkpf[] IS INITIAL.
*     No se encontraron datos para la selección ingresada
      MESSAGE i008.
      RETURN.
    ENDIF.

*   Para actualizar tabla de control al finalizar el proceso
    gv_max_date = gt_bkpf[ 1 ]-cpudt.
    gv_max_time = gt_bkpf[ 1 ]-cputm.

*   Rescatar partidas abiertas
    SELECT FROM bsid FIELDS bukrs, belnr, gjahr, dmbtr, waers
      FOR ALL ENTRIES IN @gt_bkpf
      WHERE bukrs = @gt_bkpf-bukrs
        AND belnr = @gt_bkpf-belnr
        AND gjahr = @gt_bkpf-gjahr
      INTO TABLE @DATA(lt_bsid).

    SORT lt_bsid BY bukrs belnr gjahr.

*   Rescatar partidas compensadas
    SELECT FROM bsad FIELDS bukrs, belnr, gjahr, dmbtr, waers
      FOR ALL ENTRIES IN @gt_bkpf
      WHERE bukrs = @gt_bkpf-bukrs
        AND belnr = @gt_bkpf-belnr
        AND gjahr = @gt_bkpf-gjahr
      INTO TABLE @DATA(lt_bsad).

    SORT lt_bsad BY bukrs belnr gjahr.

***
    LOOP AT gt_bkpf ASSIGNING FIELD-SYMBOL(<ls_bkpf>).
*     Busca en partidas abiertas
      READ TABLE lt_bsid ASSIGNING FIELD-SYMBOL(<ls_bsid>)
        WITH KEY bukrs = <ls_bkpf>-bukrs
                 belnr = <ls_bkpf>-belnr
                 gjahr = <ls_bkpf>-gjahr BINARY SEARCH.

      IF sy-subrc = 0.   "Partida abierta

*       Se busca si ya existe un registro para el período
        READ TABLE gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WITH KEY bukrs = <ls_bkpf>-bukrs
                                                                      gjahr = <ls_bkpf>-gjahr
                                                                      monat = <ls_bkpf>-monat.
        IF sy-subrc = 0.
*         Si existe registro, acumula los importes
          IF <ls_bkpf>-blart IN gr_blart_fc.
            <ls_data>-mntfc = <ls_data>-mntfc + <ls_bsid>-dmbtr.
          ELSE.
            <ls_data>-mntnc = <ls_data>-mntnc + <ls_bsid>-dmbtr.
          ENDIF.
        ELSE.
*         Si no existe, agrega un registro nuevo
          APPEND INITIAL LINE TO gt_data ASSIGNING <ls_data>.
          <ls_data>-bukrs = <ls_bkpf>-bukrs.
          <ls_data>-gjahr = <ls_bkpf>-gjahr.
          <ls_data>-monat = <ls_bkpf>-monat.
          IF <ls_bkpf>-blart IN gr_blart_fc.
            <ls_data>-mntfc = <ls_bsid>-dmbtr.
          ELSE.
            <ls_data>-mntnc = <ls_bsid>-dmbtr.
          ENDIF.
          <ls_data>-waers = <ls_bsid>-waers.
        ENDIF.

      ELSE.
*       Busca en partidas compensadas
        READ TABLE lt_bsad ASSIGNING FIELD-SYMBOL(<ls_bsad>)
          WITH KEY bukrs = <ls_bkpf>-bukrs
                   belnr = <ls_bkpf>-belnr
                   gjahr = <ls_bkpf>-gjahr BINARY SEARCH.
        IF sy-subrc = 0.
*         Se busca si ya existe un registro para el período
          READ TABLE gt_data ASSIGNING <ls_data> WITH KEY bukrs = <ls_bkpf>-bukrs
                                                          gjahr = <ls_bkpf>-gjahr
                                                          monat = <ls_bkpf>-monat.
          IF sy-subrc = 0.
*           Si existe registro, acumula los importes
            IF <ls_bkpf>-blart IN gr_blart_fc.
              <ls_data>-mntfc = <ls_data>-mntfc + <ls_bsad>-dmbtr.
            ELSE.
              <ls_data>-mntnc = <ls_data>-mntnc + <ls_bsad>-dmbtr.
            ENDIF.
          ELSE.
*           Si no existe, agrega un registro nuevo
            APPEND INITIAL LINE TO gt_data ASSIGNING <ls_data>.
            <ls_data>-bukrs = <ls_bkpf>-bukrs.
            <ls_data>-gjahr = <ls_bkpf>-gjahr.
            <ls_data>-monat = <ls_bkpf>-monat.
            IF <ls_bkpf>-blart IN gr_blart_fc.
              <ls_data>-mntfc = <ls_bsad>-dmbtr.
            ELSE.
              <ls_data>-mntnc = <ls_bsad>-dmbtr.
            ENDIF.
            <ls_data>-waers = <ls_bsad>-waers.
          ENDIF.
        ENDIF.
      ENDIF.

    ENDLOOP.
***
  ENDMETHOD.

  METHOD fill_ranges.

    SELECT FROM tvarvc FIELDS sign, opti, low, high
      WHERE name = 'ZPIRCOB_BLART_FC'
        AND type = 'S'
      INTO TABLE @er_blart_fc.

    IF sy-subrc <> 0.
*     Debe completar clase de documento & en STVARV
      MESSAGE i002 WITH 'ZPIRCOB_BLART_FC'.
    ENDIF.

    SELECT FROM tvarvc FIELDS sign, opti, low, high
      WHERE name = 'ZPIRCOB_BLART_NC'
        AND type = 'S'
      INTO TABLE @er_blart_nc.

    IF sy-subrc <> 0.
*     Debe completar clase de documento & en STVARV
      MESSAGE i002 WITH 'ZPIRCOB_BLART_NC'.
    ENDIF.

    APPEND LINES OF er_blart_fc TO er_blart.
    APPEND LINES OF er_blart_nc TO er_blart.

  ENDMETHOD.

  METHOD upd_logtab.

    TYPES: BEGIN OF lty_key,
             bukrs TYPE bukrs,
             perio TYPE smud_period,
           END OF lty_key,

           ltt_key TYPE STANDARD TABLE OF lty_key.

    DATA: lt_key         TYPE ltt_key,
          lt_zpircob_sum TYPE STANDARD TABLE OF zpircob_sum.

    DATA: lv_perio TYPE smud_period.


    IF gt_data[] IS INITIAL.
      me->upd_control( EXPORTING iv_bukrs     = p_bukrs
                                 iv_fefin_uef = p_fehas
                                 iv_hofin_uef = p_hohas
                     ).
*     No se encontraron datos para tratar
      MESSAGE i004.
      RETURN.
    ENDIF.

*   Crear TI con llave
    LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      APPEND INITIAL LINE TO lt_key ASSIGNING FIELD-SYMBOL(<ls_key>).
      <ls_key>-bukrs = <ls_data>-bukrs.
      <ls_key>-perio = |{ <ls_data>-gjahr }{ <ls_data>-monat }|.
    ENDLOOP.

    SELECT FROM zpircob_sum FIELDS mandt, bukrs, perio, mntfc, mntnc, waers
      FOR ALL ENTRIES IN @lt_key
      WHERE bukrs = @lt_key-bukrs
        AND perio = @lt_key-perio
      INTO TABLE @lt_zpircob_sum.

    SORT lt_zpircob_sum BY mandt bukrs perio.

*   Preparar tabla de actualización
    LOOP AT gt_data ASSIGNING <ls_data>.
      lv_perio = |{ <ls_data>-gjahr }{ <ls_data>-monat }|.
      READ TABLE lt_zpircob_sum ASSIGNING FIELD-SYMBOL(<ls_sum>)
        WITH KEY mandt = sy-mandt
                 bukrs = <ls_data>-bukrs
                 perio = lv_perio BINARY SEARCH.
      IF sy-subrc = 0.
        <ls_sum>-mntfc = <ls_sum>-mntfc + <ls_data>-mntfc.
        <ls_sum>-mntnc = <ls_sum>-mntnc + <ls_data>-mntnc.
      ELSE.
        APPEND INITIAL LINE TO lt_zpircob_sum ASSIGNING <ls_sum>.
        <ls_sum>-mandt = sy-mandt.
        <ls_sum>-bukrs = <ls_data>-bukrs.
        <ls_sum>-perio = lv_perio.
        <ls_sum>-mntfc = <ls_data>-mntfc.
        <ls_sum>-mntnc = <ls_data>-mntnc.
        <ls_sum>-waers = <ls_data>-waers.
      ENDIF.

    ENDLOOP.

    MODIFY zpircob_sum FROM TABLE lt_zpircob_sum.

    IF sy-subrc = 0.
*     Actualizar tabla de control
      me->upd_control( EXPORTING iv_bukrs     = lt_zpircob_sum[ 1 ]-bukrs
                                 iv_fefin_uef = gv_max_date
                                 iv_hofin_uef = gv_max_time
                     ).

*     Actualizar tabla de documentos tratados
      me->upd_tabla_fac( ).

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
      ls_control-fefin_uef  = iv_fefin_uef.
      ls_control-hofin_uef  = iv_hofin_uef.
    ELSE.
      ls_control-fefin_uef  = iv_fefin_uef.
      ls_control-hofin_uef  = iv_hofin_uef.
    ENDIF.
    ls_control-erdat      = sy-datum.
    ls_control-erzet      = sy-uzeit.
    ls_control-ernam      = sy-uname.

    MODIFY zpircob_control FROM ls_control.

  ENDMETHOD.

  METHOD upd_tabla_fac.

    TYPES: lty_resp_fac TYPE zpircob_resp_fac,
           ltt_resp_fac TYPE STANDARD TABLE OF lty_resp_fac.

    DATA: lt_resp_fac TYPE ltt_resp_fac.

    LOOP AT gt_bkpf ASSIGNING FIELD-SYMBOL(<ls_bkpf>).
      APPEND INITIAL LINE TO lt_resp_fac ASSIGNING FIELD-SYMBOL(<ls_resp_fac>).
      <ls_resp_fac>-bukrs = <ls_bkpf>-bukrs.
      <ls_resp_fac>-belnr = <ls_bkpf>-belnr.
      <ls_resp_fac>-gjahr = <ls_bkpf>-gjahr.
      <ls_resp_fac>-monat = <ls_bkpf>-monat.
      <ls_resp_fac>-erdat = sy-datum.
      <ls_resp_fac>-erzet = sy-uzeit.
      <ls_resp_fac>-ernam = sy-uname.
      IF <ls_bkpf>-blart IN gr_blart_nc.
        <ls_resp_fac>-vbtyp = 'O'.
      ELSE.
        <ls_resp_fac>-vbtyp = 'M'.
      ENDIF.
    ENDLOOP.

    MODIFY zpircob_resp_fac FROM TABLE lt_resp_fac.

  ENDMETHOD.

  METHOD del_void_sd.
*<-> ct_bkpf TYPE gtt_bkpf

    TYPES: BEGIN OF lty_bkpf_sd,
             bukrs TYPE bukrs,
             belnr TYPE belnr_d,
             gjahr TYPE gjahr,
             vbeln TYPE vbeln_vf,
           END OF lty_bkpf_sd,

           ltt_bkpf_sd TYPE STANDARD TABLE OF lty_bkpf_sd.

    DATA: lt_bkpf_sd TYPE ltt_bkpf_sd.

*   Determina los registros correspondientes a documentos SD
    LOOP AT ct_bkpf ASSIGNING FIELD-SYMBOL(<ls_bkpf>) WHERE awtyp = 'VBRK'.
      APPEND INITIAL LINE TO lt_bkpf_sd ASSIGNING FIELD-SYMBOL(<ls_bkpf_sd>).
      MOVE-CORRESPONDING <ls_bkpf> TO <ls_bkpf_sd>.
      <ls_bkpf_sd>-vbeln = <ls_bkpf>-awkey.
    ENDLOOP.

    CHECK NOT lt_bkpf_sd[] IS INITIAL.

*   Rescata los documentos SD anulados
    SELECT FROM vbrk FIELDS vbeln, fksto
      FOR ALL ENTRIES IN @lt_bkpf_sd
      WHERE vbeln  = @lt_bkpf_sd-vbeln
        AND fksto <> ' '
      INTO TABLE @DATA(lt_vbrk_anu).

    CHECK NOT lt_vbrk_anu[] IS INITIAL.
    SORT lt_vbrk_anu BY vbeln.

*   Elimina documentos SD anulados de la tabla principal
    LOOP AT ct_bkpf ASSIGNING <ls_bkpf>.
      READ TABLE lt_vbrk_anu TRANSPORTING NO FIELDS
        WITH KEY vbeln = <ls_bkpf>-awkey BINARY SEARCH.
      IF sy-subrc = 0.
        DELETE ct_bkpf.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
