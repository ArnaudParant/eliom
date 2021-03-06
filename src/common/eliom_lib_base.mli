(* Ocsigen
 * http://www.ocsigen.org
 * Copyright (C) 2011 Grégoire Henry
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

open Ocsigen_lib_base

exception Eliom_Internal_Error of string

(** Module with Lwt operators: Open to use them without polluting your scope. *)
module Lwt_ops : sig
  val ( >>= ) : 'a Lwt.t -> ('a -> 'b Lwt.t) -> 'b Lwt.t
  val ( =<< ) : ('a -> 'b Lwt.t) -> 'a Lwt.t -> 'b Lwt.t
  val ( >|= ) : 'a Lwt.t -> ('a -> 'b) -> 'b Lwt.t
  val ( =|< ) : ('a -> 'b) -> 'a Lwt.t -> 'b Lwt.t
end

val escape_quotes : string -> string

module type Map_S = sig
  include Map.S
  val from_list : (key * 'a) list -> 'a t
  val to_string : ?sep:string -> ('a -> string) -> 'a t -> string
end

module Int64_map : Map_S with type key = int64
module Int_map : Map_S with type key = int
module String_map : Map_S with type key = string

(**/**)

(** Server representation of client values.
    Developer-visible functions should always operate on
    {% <<a_api subproject="server" | type Eliom_pervasives.client_value >> %} or
    {% <<a_api subproject="server" | type Eliom_lib.client_value >> %}.
  *)
module Client_value_server_repr : sig
  type +'a t
  val create: closure_id:int64 -> instance_id:int64 -> _ t
  val closure_id: _ t -> int64
  val instance_id: _ t -> int64
end

(** The representation of escaped values (values injected into client
    values) is opaque. *)
type escaped_value = poly

val fresh_ix : unit -> int64
val get_option : 'a option -> 'a

module RawXML : sig

  type separator = Space | Comma

  val separator_to_string : separator -> string

  type cookie_info = (bool * string list) deriving (Json)

  type -'a caml_event_handler =
    | CE_registered_closure of string * ((#Dom_html.event as 'a) Js.t -> unit) Client_value_server_repr.t
    | CE_client_closure of ('a Js.t -> bool) (* Client side-only *)
    | CE_call_service of
        ([ `A | `Form_get | `Form_post] * (cookie_info option) * string option) option Eliom_lazy.request

  type event_handler =
    | Raw of string
    | Caml of Dom_html.event caml_event_handler

  type uri = string Eliom_lazy.request
  val string_of_uri : uri -> string
  val uri_of_string : string -> uri
  val uri_of_fun : (unit -> string) -> uri

  val event_handler_of_string : string -> event_handler
  val string_of_event_handler : event_handler -> string
  val event_handler_of_service :
    ([ `A | `Form_get | `Form_post] * (cookie_info option) * string option) option Eliom_lazy.request ->
      event_handler

  val ce_registered_closure_class : string
  val ce_call_service_class : string
  val process_node_class : string
  val request_node_class : string

  val ce_call_service_attrib : string
  val ce_template_attrib : string
  val node_id_attrib : string

  val closure_attr_prefix : string
  val closure_attr_prefix_len : int

  type aname = string
  type acontent =
    | AFloat of float
    | AInt of int
    | AStr of string
    | AStrL of separator * string list
  type racontent =
    | RA of acontent
    | RACamlEventHandler of Dom_html.event caml_event_handler
    | RALazyStr of string Eliom_lazy.request
    | RALazyStrL of separator * string Eliom_lazy.request list
  type attrib = aname * racontent
  val aname : attrib -> aname
  val acontent : attrib -> acontent
  val racontent : attrib -> racontent

  val float_attrib : aname -> float -> attrib
  val int_attrib : aname -> int -> attrib
  val string_attrib : aname -> string -> attrib
  val space_sep_attrib : aname -> string list -> attrib
  val comma_sep_attrib : aname -> string list -> attrib
  val event_handler_attrib : aname -> event_handler -> attrib
  val uri_attrib : aname -> string Eliom_lazy.request -> attrib
  val uris_attrib : aname -> string Eliom_lazy.request list -> attrib

  type ename = string
  type node_id =
    | NoId
    | ProcessId of string
    | RequestId of string

  module ClosureMap : Map.S with type key = string (* crypto *)

  type event_handler_table =
    ((Dom_html.event Js.t -> unit) Client_value_server_repr.t) ClosureMap.t

  val filter_class_attribs : node_id -> (string * racontent) list -> (string * racontent) list
end

val tyxml_unwrap_id_int : int
val client_value_unwrap_id_int : int

(** Data for initializing one client value *)
type client_value_datum = {
  closure_id : int64;
  instance_id : int64;
  args : poly;
}

(** Data for initializing one injection *)
type 'injection_value injection_datum = {
  injection_id : string;
  injection_value : 'injection_value;
}

(** Data for initializing client values and injections of one compilation unit *)
type 'injection_value compilation_unit_global_data = {
  mutable server_sections_data : (client_value_datum list) Queue.t;
  mutable client_sections_data : ('injection_value injection_datum list) Queue.t;
}

(** Data for initializing client values and injection of the client
    program. Sent with the response to the initial request of a client
    process. *)
type 'injection_value global_data =
    'injection_value compilation_unit_global_data String_map.t

(** Data for initializing client values sent with a request. Sent with
    the response to any follow-up request of a client process. *)
type request_data = client_value_datum list

val global_data_unwrap_id_int : int

val global_data_to_string : _ global_data -> string
val request_data_to_string : request_data -> string
