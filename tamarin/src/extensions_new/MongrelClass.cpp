
#include "avmshell.h"
#include <cstring>
#include <string>
#include <iostream>
#include <sstream>

using namespace std;


namespace avmplus {

    MongrelObject::MongrelObject(VTable* vtable, ScriptObject* delegate)
    : ScriptObject(vtable, delegate) {

    }

    MongrelClass::MongrelClass(VTable *cvtable)
    : ClassClosure(cvtable) {
        createVanillaPrototype();
    }

    ByteArrayObject* MongrelObject::receive() {
        char * data;
        req = conn->recv();
        data = new char [req.body.size() + 1];
        strcpy(data, req.body.c_str());

        ByteArrayObject* b;
        b = toplevel()->byteArrayClass()->constructByteArray();
        b->set_length(0);
        b->set_position(0);
        b->GetByteArray().Write(data, strlen(data));
        return b;
    }

    bool MongrelObject::send(ByteArrayObject* message) {
        uint32_t len = message->GetByteArray().GetLength();
        const uint8_t* c = message->GetByteArray().GetReadableBuffer();
        std::string str((const char*) c, len);
        std::ostringstream response;
        response << "<pre>" << std::endl;
        response << "SENDER: " << req.sender << std::endl;
        response << "IDENT: " << req.conn_id << std::endl;
        response << "PATH: " << req.path << std::endl;
        response << "BODY: " << req.body << std::endl;
        for (std::vector<m2pp::header>::iterator it = req.headers.begin(); it != req.headers.end(); it++) {
            response << "HEADER: " << it->first << ": " << it->second << std::endl;
        }
        response << "</pre>" << std::endl;

        std::cout << response.str();

        conn->reply_http(req, response.str());
        return true;
    }

    bool MongrelObject::connect(Stringp _sender_id, Stringp _sub_address, Stringp _pub_address) {
        StUTF8String sender_idUTF8(_sender_id);
        std::string sender_id = sender_idUTF8.c_str();

        StUTF8String sub_addressUTF8(_sub_address);
        std::string sub_address = sub_addressUTF8.c_str();

        StUTF8String pub_addressUTF8(_pub_address);
        std::string pub_address = pub_addressUTF8.c_str();
        //std::string sender_id = "82209006-86FF-4982-B5EA-D1E29E55D481";

        //m2pp::connection conn(sender_id, "tcp://127.0.0.1:9999", "tcp://127.0.0.1:9998");
        conn = new m2pp::connection(sender_id, sub_address, pub_address);

        return true;
    }

}
