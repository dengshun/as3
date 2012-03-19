#ifndef __avmplus_MongrelClass__
#define __avmplus_MongrelClass__
#include <zmq.hpp>
#include "m2pp.hpp"
#include "shell_toplevel-classes.hh"


namespace avmplus {

    class MongrelObject : public ScriptObject {
    public:
        MongrelObject(VTable* vtable, ScriptObject* delegate);
        
        bool connect(Stringp _sender_id, Stringp _sub_address, Stringp _pub_address);
        ByteArrayObject* receive();
        bool send(ByteArrayObject* message);
        m2pp::connection * conn;
        m2pp::request req;
        

    private:

        DECLARE_SLOTS_MongrelObject;


    };

    class MongrelClass : public ClassClosure {
    public:
        MongrelClass(VTable* vtable);

        DECLARE_SLOTS_MongrelClass;
    };


}
#endif 