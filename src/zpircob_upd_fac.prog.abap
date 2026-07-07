*&---------------------------------------------------------------------*
*& Report ZPIRCOB_UPD_FAC
*&---------------------------------------------------------------------*
*& Compañía   : HELP
*& Autor      : Vision One # CNN
*& Fecha      : 07.11.2023
*& Objetivo   : Rescata los documentos de facturación en un período y
*&              actualiza la tabla de totales de facturación
*&              STVARV: ZPIRCOB_UPD_FAC_FEMIN - Fecha incial de control
*&                      ZPIRCOB_BLART_FC - Clases de documento facturas
*&                      ZPIRCOB_BLART_NC - Clases de documento NC
*&              Transacción: ZFI_PCFAC
*&---------------------------------------------------------------------
*&                       MODIFICACIONES
*&---------------------------------------------------------------------
*& Modificó   :
*& Fecha      :
*& Solicitó   :
*& Transporte :
*& Objetivo   :
*&---------------------------------------------------------------------
REPORT zpircob_upd_fac MESSAGE-ID zpircob.

INCLUDE zpircob_upd_fac_top.   "Declaraciones globales
INCLUDE zpircob_upd_fac_sel.   "Pantalla de inicio
INCLUDE zpircob_upd_fac_f01.   "Rutinas locales
INCLUDE zpircob_upd_fac_cla.   "Clases


*--------------------------------------------------------------------*
*                     BEGIN
*--------------------------------------------------------------------*
START-OF-SELECTION.

  DATA(go_app) = NEW lcl_app( ).

  go_app->get_data( EXPORTING iv_bukrs = p_bukrs
                              iv_fehas = p_fehas
                              iv_hohas = p_hohas
  ).

  IF p_test = abap_false.
    go_app->upd_logtab( ).
*   Proceso finalizado
    MESSAGE i006.
  ELSE.
    go_app->show_data( ).
  ENDIF.
