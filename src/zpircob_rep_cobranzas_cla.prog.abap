*&---------------------------------------------------------------------*
*&  Include           ZPIRCOB_REP_COBRANZAS_CLA
*&---------------------------------------------------------------------*

CLASS lcl_reporte DEFINITION.

  PUBLIC SECTION.

    TYPES: gty_sal TYPE zpircob_alv_rep_cobranzas.

    TYPES: BEGIN OF gty_orden_periodo,
             fieldname TYPE slis_fieldname,
             gjahr     TYPE gjahr,
             monat     TYPE monat,
           END OF gty_orden_periodo.

    TYPES: gtt_sal           TYPE STANDARD TABLE OF gty_sal,
           gtt_orden_periodo TYPE STANDARD TABLE OF gty_orden_periodo.

    DATA: gt_sal           TYPE gtt_sal,
          gt_orden_periodo TYPE gtt_orden_periodo.

    DATA: gv_bukrs TYPE bukrs,
          gv_perio TYPE smud_period.

    METHODS:
      constructor IMPORTING iv_bukrs TYPE bukrs
                            iv_gjahr TYPE gjahr
                            iv_monat TYPE monat,

      fill_fac_data,

      fill_cob_data,

      show.

  PRIVATE SECTION.
    METHODS:
      get_perio_has IMPORTING iv_perio_des TYPE smud_period
                    EXPORTING ev_perio_has TYPE smud_period,

      fill_layout EXPORTING es_layout        TYPE slis_layout_alv
                            es_grid_settings TYPE lvc_s_glay,

      fill_fieldcat EXPORTING et_fieldcat    TYPE slis_t_fieldcat_alv,

      get_index IMPORTING iv_perio_desde TYPE smud_period
                          iv_perio_c     TYPE zde_perio_c
                EXPORTING ev_index       TYPE numc2,

      get_titles IMPORTING iv_fieldname TYPE slis_fieldname
                 CHANGING  cs_fieldcat  TYPE slis_fieldcat_alv.

ENDCLASS.

CLASS lcl_reporte IMPLEMENTATION.

  METHOD constructor.

    CLEAR: gt_sal, gt_orden_periodo.

    gv_bukrs = iv_bukrs.
    gv_perio = |{ iv_gjahr }{ iv_monat }|.

  ENDMETHOD.

  METHOD fill_fac_data.

    DATA: lv_perio_des TYPE smud_period,
          lv_perio_has TYPE smud_period.


*   Período desde es el que se ingreso por selección
    lv_perio_des = gv_perio.

    me->get_perio_has( EXPORTING iv_perio_des = lv_perio_des
                       IMPORTING ev_perio_has = lv_perio_has
                     ).

    SELECT FROM zpircob_sum FIELDS perio, mntfc, mntnc, waers
      WHERE bukrs = @gv_bukrs
        AND perio BETWEEN @lv_perio_des AND @lv_perio_has
      ORDER BY perio
      INTO TABLE @DATA(lt_fac).

    CHECK NOT lt_fac IS INITIAL.

    LOOP AT lt_fac ASSIGNING FIELD-SYMBOL(<ls_fac>).
      APPEND INITIAL LINE TO gt_sal ASSIGNING FIELD-SYMBOL(<ls_sal>).
      <ls_sal>-perio_f  = <ls_fac>-perio.
      <ls_sal>-perio_fc = |{ <ls_fac>-perio+0(4) }-{ <ls_fac>-perio+4(2) }|.
      <ls_sal>-mntfc    = <ls_fac>-mntfc.
      <ls_sal>-mntnc    = <ls_fac>-mntnc.
      <ls_sal>-total    = <ls_fac>-mntfc - <ls_fac>-mntnc.
      <ls_sal>-waers    = <ls_fac>-waers.
    ENDLOOP.

  ENDMETHOD.


  METHOD fill_cob_data.

    DATA: ls_sal TYPE gty_sal.

    DATA: lv_perio_des TYPE smud_period,
          lv_perio_has TYPE smud_period,
          lv_index     TYPE n LENGTH 2,
          lv_fieldname TYPE fieldname.

    FIELD-SYMBOLS: <fs_fieldname> TYPE any.


*   Período desde es el que se ingreso por selección
    lv_perio_des = gv_perio.

    me->get_perio_has( EXPORTING iv_perio_des = lv_perio_des
                       IMPORTING ev_perio_has = lv_perio_has
                     ).

    SELECT FROM zpircob_sum_c FIELDS perio_f, perio_c, mntco
      WHERE bukrs = @gv_bukrs
        AND perio_f BETWEEN @lv_perio_des AND @lv_perio_has
      ORDER BY perio_f, perio_c
      INTO TABLE @DATA(lt_cob).

***
    LOOP AT gt_sal INTO ls_sal.
      CLEAR: lv_index.
**
      LOOP AT lt_cob ASSIGNING FIELD-SYMBOL(<ls_cob>) WHERE perio_f = ls_sal-perio_f.
        CHECK <ls_cob>-perio_c >= gv_perio.

        me->get_index( EXPORTING iv_perio_desde = gv_perio
                                 iv_perio_c     = <ls_cob>-perio_c
                       IMPORTING ev_index       = lv_index
                     ).
*-> BEG INS V1-CNN 04.04.2024 ECDK925049
        IF lv_index > 24.
          EXIT.
        ENDIF.
*-> END INS V1-CNN 04.04.2024 ECDK925049
        lv_fieldname = |LS_SAL-COB{ lv_index } |.
        ASSIGN (lv_fieldname) TO <fs_fieldname>.

        <fs_fieldname> = <ls_cob>-mntco.

      ENDLOOP.
**
      IF sy-subrc = 0.
        MODIFY gt_sal FROM ls_sal.
      ENDIF.

    ENDLOOP.
***

  ENDMETHOD.

  METHOD show.

    DATA: ls_layout        TYPE slis_layout_alv,
          ls_grid_settings TYPE lvc_s_glay.

    DATA: lt_fieldcat TYPE slis_t_fieldcat_alv.


    IF gt_sal[] IS INITIAL.
*     No se encontraron datos para la selección ingresada
      MESSAGE i008.
      RETURN.
    ENDIF.

*   cl_demo_output=>display( gt_sal ).

    fill_layout( IMPORTING es_layout        = ls_layout
                           es_grid_settings = ls_grid_settings
               ).

    fill_fieldcat( IMPORTING et_fieldcat = lt_fieldcat ).

    DATA(lv_repid) = sy-repid.

    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        i_callback_program       = lv_repid
        i_callback_user_command  = 'USER_COMMAND'
        i_callback_pf_status_set = 'PF_STATUS'
        it_fieldcat              = lt_fieldcat
*       it_events                = lt_events
        is_layout                = ls_layout
        i_save                   = abap_true
*       is_variant               = gs_variant
        i_grid_settings          = ls_grid_settings
      TABLES
        t_outtab                 = gt_sal
      EXCEPTIONS
        program_error            = 1
        OTHERS                   = 2.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.


  ENDMETHOD.

  METHOD get_perio_has.
*-> iv_perio_des TYPE smud_period
*<- ev_perio_has TYPE smud_period.
    DATA: lv_anio  TYPE gjahr,
          lv_fecha TYPE sydatum.

    lv_anio = iv_perio_des+0(4).
    lv_anio = lv_anio + 2.

    lv_fecha = |{ lv_anio }{ iv_perio_des+4(2) }01|.
    lv_fecha = lv_fecha - 1.

    ev_perio_has = lv_fecha+0(6).

  ENDMETHOD.

  METHOD fill_layout.

    CLEAR: es_layout.

    es_layout-zebra              = abap_true.
    es_layout-colwidth_optimize  = p_opti.
    es_layout-f2code             = 'DOBCLICK'.
*   es_layout-numc_sum           = 'X'.
*   es_layout-box_fieldname      = 'FLAG'.
*   es_layout-coltab_fieldname   = 'COLOR'.

*   Traspasar edición de ALV a tabla interna
    es_grid_settings-edt_cll_cb  = 'X'.
    es_grid_settings-coll_top_p  = 'X'.
    es_grid_settings-coll_end_l  = 'X'.

  ENDMETHOD.

  METHOD fill_fieldcat.

    DATA: ls_structure_name TYPE tabname.

    DATA: lt_fieldcat TYPE slis_t_fieldcat_alv.

    ls_structure_name = 'ZPIRCOB_ALV_REP_COBRANZAS'.

    CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name = ls_structure_name
      CHANGING
        ct_fieldcat      = lt_fieldcat.

    LOOP AT  lt_fieldcat ASSIGNING FIELD-SYMBOL(<ls_fieldcat>).
      IF <ls_fieldcat>-fieldname+0(3) = 'COB'.
        me->get_titles( EXPORTING iv_fieldname = <ls_fieldcat>-fieldname
                        CHANGING  cs_fieldcat  = <ls_fieldcat>
                      ).
      ENDIF.

      IF <ls_fieldcat>-fieldname = 'PERIO_F ' OR <ls_fieldcat>-fieldname = 'WAERS'.
        <ls_fieldcat>-no_out = abap_true.
      ENDIF.

*      IF <ls_fieldcat>-fieldname = 'MNTFC' OR <ls_fieldcat>-fieldname = 'MNTNC'.
*        <ls_fieldcat>-hotspot = abap_true.
*      ENDIF.

    ENDLOOP.

    et_fieldcat[] = lt_fieldcat[].

  ENDMETHOD.

  METHOD get_index.
*-> iv_perio_desde TYPE smud_period
*-> iv_perio_c     TYPE zde_perio_c
*<- ev_index       TYPE numc2.
    DATA: lv_feini  TYPE sydatum,
          lv_fefin  TYPE sydatum,
          lv_months TYPE tfmatage.

    lv_feini = |{ iv_perio_desde }01|.
    lv_fefin = |{ iv_perio_c }01|.

*   Determina la cantidad de meses de diferencia
    CALL FUNCTION 'FIMA_DAYS_AND_MONTHS_AND_YEARS'
      EXPORTING
        i_date_from    = lv_feini
        i_date_to      = lv_fefin
        i_flg_round_up = ' '
      IMPORTING
        e_months       = lv_months.


    ev_index = lv_months + 1.

  ENDMETHOD.

  METHOD get_titles.
*->  iv_fieldname TYPE slis_fieldname
*<-> cs_fieldcat  TYPE slis_fieldcat_alv.

    DATA: lv_feini     TYPE sydatum,
          lv_index     TYPE numc2,
          lv_calc_date TYPE sydatum.

    lv_feini = |{ gv_perio }01|.
    lv_index = iv_fieldname+3(2).
    lv_index = lv_index - 1.

    CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
      EXPORTING
        date      = lv_feini
        days      = '00'
        months    = lv_index
        years     = '00'
      IMPORTING
        calc_date = lv_calc_date.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    cs_fieldcat-seltext_s    = |{ lv_calc_date+0(4) }-{ lv_calc_date+4(2) }|.
    cs_fieldcat-seltext_m    = |{ lv_calc_date+0(4) }-{ lv_calc_date+4(2) }|.
    cs_fieldcat-seltext_l    = |{ lv_calc_date+0(4) }-{ lv_calc_date+4(2) }|.
    cs_fieldcat-reptext_ddic = |{ lv_calc_date+0(4) }-{ lv_calc_date+4(2) }|.

    APPEND INITIAL LINE TO gt_orden_periodo ASSIGNING FIELD-SYMBOL(<ls_op>).
    <ls_op>-fieldname = iv_fieldname.
    <ls_op>-gjahr     = lv_calc_date+0(4).
    <ls_op>-monat     = lv_calc_date+4(2).

  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
*       CLASS cl_event_handler DEFINITION
*----------------------------------------------------------------------*
CLASS cl_event_handler DEFINITION.

  PUBLIC SECTION.

    CLASS-DATA: lo_alv_object TYPE REF TO cl_salv_table.

    CLASS-METHODS on_function_click
      FOR EVENT if_salv_events_functions~added_function
        OF cl_salv_events_table IMPORTING e_salv_function.

ENDCLASS.                    "cl_event_handler DEFINITION


*----------------------------------------------------------------------*
*       CLASS cl_event_handler IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS cl_event_handler IMPLEMENTATION.

  METHOD on_function_click.

    CASE e_salv_function.
      WHEN 'GOON'.
        lo_alv_object->close_screen( ).
      WHEN 'ABR'.
        lo_alv_object->close_screen( ).
    ENDCASE.
  ENDMETHOD.                    "on_function_click

ENDCLASS.                    "cl_event_handler IMPLEMENTATION
