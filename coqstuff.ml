open Soup
let newparse  a = Markup.string a |> Markup.parse_xml |> Markup.signals |> from_signals;;

let  readFromCoq oc () = 
  let bb=Bytes.create 10000000 in 
  let i=Unix.read (Unix.descr_of_in_channel oc) bb 0 10000000 in
  Bytes.sub bb  0 i;;
let rec stringReadFromCoq oc n = try readFromCoq oc () with
any-> stringReadFromCoq oc ();;


let rec readytoread ic oc =
let a, b, c = Unix.select [Unix.descr_of_in_channel oc] [Unix.descr_of_out_channel ic] [] 25.0 in
a != [];;

let nonblockread ic oc =
if readytoread ic oc then Some (readFromCoq oc ())
else  (  None);;

let rec repeatreading ic oc =
let x = nonblockread ic oc in
match x with
Some a -> a 
|None-> ( repeatreading ic oc);;


let get_opsys () =
  let ic = Unix.open_process_in "uname" in
  let uname = input_line ic in
  let () = close_in ic in
 uname;;


let isMac ()=
(try (Str.search_forward (Str.regexp "Unix") (Sys.os_type) 0)>=0 with _-> false) &&
(try (Str.search_forward (Str.regexp "Darw") (get_opsys ()) 0)>=0 with _-> false)
let isLinux ()=
(try (Str.search_forward (Str.regexp "Unix") (Sys.os_type) 0)>=0 with _-> false) &&
(try (Str.search_forward (Str.regexp "Linux") (get_opsys ()) 0)>=0 with _-> false)
let isWin ()=
try (Str.search_forward (Str.regexp "Win") (Sys.os_type) 0)>=0 with _-> false

let rec getmessages ic oc l =
let rec sgoal ic oc () = ignore (Printf.fprintf ic "%s" "<call  val =\"Goal\"><unit/></call>\n";flush_all ());
let x = if isWin () then repeatreading ic oc  else stringReadFromCoq oc () in
if x!="" then try newparse x with _ -> sgoal ic oc () else sgoal ic oc () in
 let x = sgoal ic oc () in 
  if (List.mem (to_string x) (List.map to_string l) ) then l else getmessages ic oc (l@[x]);;

let rec mygoal ic oc str = ignore (Printf.fprintf ic "%s" "<call  val =\"Goal\"><unit/></call>\n";flush_all ());
let x = if isWin () then repeatreading ic oc  else stringReadFromCoq oc () in
if str = x then x else ( mygoal ic oc x);;

let rec soupgoal ic oc () = 
let x = mygoal ic oc "" in
try newparse x with _ -> soupgoal ic oc ();;

let rec readnow ic oc str =
let a, b, c = Unix.select [Unix.descr_of_in_channel oc] [Unix.descr_of_out_channel ic] [] 25.0 in
if a != [] then
let x= (readFromCoq (Unix.in_channel_of_descr (List.hd a)) ()) in
 readnow ic oc (str^x) else str;;



let evars ic () = Printf.fprintf ic "<call val=\"Evars\"><unit/></call>\n";flush_all ();;
let status ic () = Printf.fprintf ic "%s" "<call val=\"Status\"><bool val=\"false\"/></call>";flush_all ();;
let rec soupstatus ic oc () = ignore (status ic ()); try newparse (stringReadFromCoq oc ()) with _ -> soupstatus ic oc ();;
(* let addtext str i = "</call><call val='Add'><pair><pair><string>"^str^"</string>
<int>0</int></pair><pair><state_id val='"^i^"'/><bool val='false'/></pair></pair></call>\n";; *)
let writeToCoq ic  str i = Printf.fprintf ic "%s"  (Processinputs.addtext str i) ;flush_all ()
   
let printAST ic i = Printf.fprintf ic "%s" ("<call val=\"PrintAst\"><state_id val=\""^i^"\"/></call>");flush_all ();;
let movebackto ic i = Printf.fprintf ic "%s" ("<call val=\"Edit_at\"><state_id val=\""^i^"\"/></call>");flush_all ();;


let rec findstateid ic oc id = match (attribute "val" ((soupstatus ic oc  ()) $ "state_id")) with
   Some x -> if int_of_string x >= int_of_string id then x else findstateid ic oc id
  |_ -> findstateid ic oc id;;
let rec fstid ic oc id = try (findstateid ic oc id) with any -> ignore (Printf.printf "%s" (Printexc.to_string any)); fstid ic oc id;;
