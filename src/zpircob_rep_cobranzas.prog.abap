*&---------------------------------------------------------------------*
*& Report ZPIRCOB_REP_COBRANZAS
*&---------------------------------------------------------------------*
*& Compañía   : HELP
*& Autor      : Vision One # CNN
*& Fecha      : 04.12.2023
*& Objetivo   : Mostrar la facturación de un período contra las cobranzas
*&              del mismo período.
*&              Transacción ZFI_PCREP
*&
*&
*&---------------------------------------------------------------------
*&                       MODIFICACIONES
*&---------------------------------------------------------------------
*& Modificó   :
*& Fecha      :
*& Solicitó   :
*& Transporte :
*& Objetivo   :
*&---------------------------------------------------------------------
REPORT zpircob_rep_cobranzas MESSAGE-ID zpircob.

INCLUDE zpircob_rep_cobranzas_top.    "Declaraciones globales
INCLUDE zpircob_rep_cobranzas_sel.    "Pantalla de inicio
INCLUDE zpircob_rep_cobranzas_cla.    "Clases
* INCLUDE zpircob_rep_cobranzas_f01.    "Rutinas locales

*--------------------------------------------------------------------*
*                     BEGIN
*--------------------------------------------------------------------*
START-OF-SELECTION.

  DATA(go_reporte) = NEW lcl_reporte( iv_bukrs = p_bukrs
                                      iv_gjahr = p_gjahr
                                      iv_monat = p_monat
                                      ).

  go_reporte->fill_fac_data( ).

  go_reporte->fill_cob_data( ).

  go_reporte->show( ).

INCLUDE zpircob_rep_cobranzas_f01.    "Rutinas locales
