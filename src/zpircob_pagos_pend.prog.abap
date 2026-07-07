*&---------------------------------------------------------------------*
*& Report ZPIRCOB_UPD_PAGOS
*&---------------------------------------------------------------------*
*& Compañía   : HELP
*& Autor      : Vision One # CNN
*& Fecha      : 12.12.2023
*& Objetivo   : Rescata los pagos de los documentos de pagos pendientes
*&              y actualiza la tabla de totales de pagos
*&              Transacción ZFI_PAGPEN
*&---------------------------------------------------------------------
*&                       MODIFICACIONES
*&---------------------------------------------------------------------
*& Modificó   :
*& Fecha      :
*& Solicitó   :
*& Transporte :
*& Objetivo   :
*&---------------------------------------------------------------------
REPORT zpircob_pagos_pend MESSAGE-ID zpircob.

INCLUDE zpircob_pagos_pend_top.   "Declaraciones globales
INCLUDE zpircob_pagos_pend_sel.   "Pantalla de inicio
INCLUDE zpircob_pagos_pend_f01.   "Rutinas locales
INCLUDE zpircob_pagos_pend_cla.   "Clases

*--------------------------------------------------------------------*
*                     BEGIN
*--------------------------------------------------------------------*
START-OF-SELECTION.

  DATA(go_app) = NEW lcl_app( ).

  go_app->get_data( EXPORTING iv_bukrs = p_bukrs ).


  IF p_test = abap_false.
    go_app->upd_logtab( ).
*   Proceso finalizado
    MESSAGE i006.
  ELSE.
    go_app->show_data( ).
  ENDIF.
