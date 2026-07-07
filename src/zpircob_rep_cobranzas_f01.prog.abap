*&---------------------------------------------------------------------*
*&  Include           ZPIRCOB_REP_COBRANZAS_F01
*&---------------------------------------------------------------------*
*--------------------------------------------------------------------*
*&   Form  PF_STATUS
*--------------------------------------------------------------------*
FORM pf_status USING ce_func_exclude TYPE slis_t_extab.

  DATA: lt_code_attrib_tab  TYPE TABLE OF smp_dyntxt.
  DATA: ls_code_attrib_tab  TYPE smp_dyntxt.
  DATA: ls_exlude           TYPE slis_extab.

  DEFINE exclude.
    CLEAR: ls_exlude.
    ls_exlude-fcode = &1.
    APPEND ls_exlude TO ce_func_exclude.
  END-OF-DEFINITION.

  SET PF-STATUS 'ALVLIST'  EXCLUDING ce_func_exclude.

ENDFORM.  " FIN PF_STATUS


*--------------------------------------------------------------------*
*&   Form  USER_COMMAND
*--------------------------------------------------------------------*
FORM user_command USING iv_ucomm    TYPE syucomm
                        is_selfield TYPE slis_selfield.

  DATA: lv_answer TYPE c LENGTH 1.

  CASE iv_ucomm.
*    WHEN 'FC01'.
*      LEAVE TO SCREEN 0.

*    WHEN 'FC02'.

    WHEN 'DOBCLICK'.
      READ TABLE go_reporte->gt_sal ASSIGNING FIELD-SYMBOL(<ls_sal>) INDEX is_selfield-tabindex.
      IF sy-subrc = 0.
        CASE is_selfield-fieldname.
          WHEN 'MNTFC'.
            PERFORM show_doc_fc USING <ls_sal> p_bukrs 'M'.
          WHEN 'MNTNC'.
            PERFORM show_doc_fc USING <ls_sal> p_bukrs 'O'.
          WHEN OTHERS.
            IF is_selfield-fieldname+0(3) = 'COB'.
              READ TABLE go_reporte->gt_orden_periodo ASSIGNING FIELD-SYMBOL(<ls_op>)
                WITH KEY fieldname = is_selfield-fieldname.
              IF sy-subrc = 0.
                PERFORM show_cob USING  p_bukrs <ls_op>-gjahr <ls_op>-monat <ls_sal>-perio_f.
              ENDIF.
            ENDIF.
        ENDCASE.
      ENDIF.

    WHEN OTHERS.

  ENDCASE.

  CLEAR: iv_ucomm, sy-ucomm.

  is_selfield-row_stable = 'X'.
  is_selfield-col_stable = 'X'.

* Aplicar cambios realizados en GT_SAL
  is_selfield-refresh = 'X'.

ENDFORM.

*--------------------------------------------------------------------*
*  Form SHOW_DOC_FC
*--------------------------------------------------------------------*
FORM show_doc_fc USING is_sal   TYPE go_reporte->gty_sal
                       iv_bukrs TYPE bukrs
                       iv_vbtyp TYPE vbtyp.

  TYPES: BEGIN OF lty_fac,
           bukrs TYPE bukrs,
           belnr TYPE belnr_d,
           gjahr TYPE gjahr,
         END OF lty_fac,

         ltt_fac TYPE STANDARD TABLE OF lty_fac.

  DATA: lo_columns    TYPE REF TO cl_salv_columns_table,
        lo_alv_object TYPE REF TO cl_salv_table,
        lo_events     TYPE REF TO cl_salv_events_table.

  DATA: lt_fac   TYPE ltt_fac.

  DATA: lv_gjahr TYPE gjahr,
        lv_monat TYPE monat.

  CLEAR: lt_fac[].

  lv_gjahr = is_sal-perio_f+0(4).
  lv_monat = is_sal-perio_f+4(2).

  SELECT FROM zpircob_resp_fac FIELDS bukrs, belnr, gjahr
    WHERE bukrs = @iv_bukrs
      AND gjahr = @lv_gjahr
      AND monat = @lv_monat
      AND vbtyp = @iv_vbtyp
    ORDER BY bukrs, belnr
    INTO TABLE @lt_fac.

  CHECK NOT lt_fac[] IS INITIAL.

  TRY.
      CALL METHOD cl_salv_table=>factory
        IMPORTING
          r_salv_table = lo_alv_object
        CHANGING
          t_table      = lt_fac.
    CATCH cx_salv_msg.
*     Error al intentar mostrar el detalle
      MESSAGE TEXT-e01 TYPE 'I'.
  ENDTRY.

* Register handler for actions
  lo_events = lo_alv_object->get_event( ).
  SET HANDLER cl_event_handler=>on_function_click FOR lo_events.

* Save reference to access object from handler
  cl_event_handler=>lo_alv_object = lo_alv_object.

* Usar status gui ST850 del programa SAPLKKB
  lo_alv_object->set_screen_status( pfstatus = 'ST850'
                                    report   = 'SAPLKKBL' ).

* Dimensiones del popup
  lo_alv_object->set_screen_popup( start_column = 35    " Columna de Inicio
                                   start_line   = 3     " Fila de Inicio
                                   end_column   = 80   " Ancho Ventana
                                   end_line     = 17 ). " Largo Ventana

  lo_columns = lo_alv_object->get_columns( ).
  lo_columns->set_optimize( 'X' ).

* Visualizar ALV
  lo_alv_object->display( ).

ENDFORM.


*&---------------------------------------------------------------------*
*&      Form  SHOW_COB
*&---------------------------------------------------------------------*
FORM show_cob  USING iv_bukrs    TYPE bukrs
                     iv_gjahr    TYPE gjahr
                     iv_monat    TYPE monat
                     iv_perio_f  TYPE zde_perio_f.

  TYPES: BEGIN OF lty_pag,
           bukrs TYPE bukrs,
           belnr TYPE belnr_d,
           gjahr TYPE gjahr,
         END OF lty_pag,

         ltt_pag TYPE STANDARD TABLE OF lty_pag.

  DATA: lo_columns    TYPE REF TO cl_salv_columns_table,
        lo_alv_object TYPE REF TO cl_salv_table,
        lo_events     TYPE REF TO cl_salv_events_table.

  DATA: lt_pag   TYPE ltt_pag.

  CLEAR: lt_pag[].

  SELECT FROM zpircob_resp_pag FIELDS bukrs, belnr, gjahr
    WHERE bukrs   = @iv_bukrs
      AND gjahr   = @iv_gjahr
      AND monat   = @iv_monat
      AND perio_f = @iv_perio_f
    ORDER BY bukrs, belnr
    INTO TABLE @lt_pag.

  CHECK NOT lt_pag[] IS INITIAL.

  TRY.
      CALL METHOD cl_salv_table=>factory
        IMPORTING
          r_salv_table = lo_alv_object
        CHANGING
          t_table      = lt_pag.
    CATCH cx_salv_msg.
*     Error al intentar mostrar el detalle
      MESSAGE TEXT-e01 TYPE 'I'.
  ENDTRY.

* Register handler for actions
  lo_events = lo_alv_object->get_event( ).
  SET HANDLER cl_event_handler=>on_function_click FOR lo_events.

* Save reference to access object from handler
  cl_event_handler=>lo_alv_object = lo_alv_object.

* Usar status gui ST850 del programa SAPLKKB
  lo_alv_object->set_screen_status( pfstatus = 'ST850'
                                    report   = 'SAPLKKBL' ).

* Dimensiones del popup
  lo_alv_object->set_screen_popup( start_column = 35    " Columna de Inicio
                                   start_line   = 3     " Fila de Inicio
                                   end_column   = 80   " Ancho Ventana
                                   end_line     = 17 ). " Largo Ventana

  lo_columns = lo_alv_object->get_columns( ).
  lo_columns->set_optimize( 'X' ).

* Visualizar ALV
  lo_alv_object->display( ).

ENDFORM.
