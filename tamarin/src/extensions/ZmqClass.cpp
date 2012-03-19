
#include "avmshell.h"
#include "zhelpers.hpp"

using namespace std;

namespace zmqplus {

    ZmqContext* ZmqContext::pInstance = NULL;

    ZmqContext* ZmqContext::GetInstance() {
        if (!pInstance) {
            pInstance = new ZmqContext();
        }
        return pInstance;
    }

    ZmqContext::ZmqContext() {
        context = new zmq::context_t(0);
        std::cout << "Creating context: " << std::endl;
    }

    ZmqSocket* ZmqSocket::pInstance = NULL;

    ZmqSocket* ZmqSocket::GetInstance() {
        if (!pInstance) {
            pInstance = new ZmqSocket();
        }
        return pInstance;
    }

    ZmqSocket::ZmqSocket() {
        ZmqContext * zmq_context = ZmqContext::GetInstance();
        zmq::context_t * context = zmq_context->context;
        socket = new zmq::socket_t(*context, ZMQ_REP);
        socket->connect("inproc://dealer2");
    }

    int Zmq::startQueue(const char *frontend_address, const char *backend_address, int io_threads = 1, bool singleton_context = false) {
        zmq::context_t * context;

        if (singleton_context) {
            ZmqContext * zmq_context = ZmqContext::GetInstance();
            context = zmq_context->context;
        } else {
            context = new zmq::context_t(io_threads);
        }


        //Socket facing clients
        void *frontend = zmq_socket(*context, ZMQ_ROUTER);
        zmq_bind(frontend, frontend_address);

        //Socket facing services
        void* backend = zmq_socket(*context, ZMQ_DEALER);
        zmq_bind(backend, backend_address);

        std::cout << "Starting QUEUE device " << frontend_address << " <-> " << backend_address << std::endl;
        //Start built-in device
        zmq_device(ZMQ_QUEUE, frontend, backend);

        zmq_close(frontend);
        zmq_close(backend);

        //We never get here
        zmq_term(*context);
        return 0;
    }

    char* Zmq::sendMessage(const char* address, char* message) {
        
        char * cstr;
        std::string msg(message);
        //std::cout << "sendMessage " << message << std::endl;
        ZmqContext * zmq_context = ZmqContext::GetInstance();
        zmq::context_t * context = zmq_context->context;
        zmq::socket_t * socket = new zmq::socket_t(*context, ZMQ_REQ);
        socket->connect(address);
        s_send(*socket, msg);
        std::string str = s_recv(*socket);
        socket->close();
        cstr = new char [str.size() + 1];
        strcpy(cstr, str.c_str());
        return cstr;
    }

}

namespace avmplus {

    ZmqObject::ZmqObject(VTable* vtable, ScriptObject* delegate)
    : ScriptObject(vtable, delegate) {

    }

    bool ZmqObject::init(int io_threads = 1, bool singleton_context = false) {
        if (singleton_context) {
            zmqplus::ZmqContext * zmq_context = zmqplus::ZmqContext::GetInstance();
            context = zmq_context->context;
        } else {
            context = new zmq::context_t(io_threads);
        }
        return true;
    }

    bool ZmqObject::connect(Stringp addressp, int type) {
        StUTF8String addressUTF8(addressp);
        std::string address = addressUTF8.c_str();
        if (address.find("inproc", 0) != string::npos) {
            //std::cout << "inproc address" << std::endl;
        }
        socket = new zmq::socket_t(*context, type);
        if (type == 8) {
            socket->bind(addressUTF8.c_str());
        } else {
            socket->connect(addressUTF8.c_str());
        }
        return true;
    }

    bool ZmqObject::disconnect() {
        socket->close();
        return true;
    }

    ByteArrayObject* ZmqObject::receive() {
        char * data;
        std::string message = s_recv(*socket);
        data = new char [message.size() + 1];
        strcpy(data, message.c_str());

        ByteArrayObject* b;
        b = toplevel()->byteArrayClass()->constructByteArray();
        b->set_length(0);
        b->set_position(0);
        b->GetByteArray().Write(data, strlen(data));
        return b;
    }

    bool ZmqObject::send(ByteArrayObject* message) {
        uint32_t len = message->GetByteArray().GetLength();
        const uint8_t* c = message->GetByteArray().GetReadableBuffer();
        std::string str((const char*) c, len);
        bool rc = s_send(*socket, str);
        return rc;
    }

    ZmqClass::ZmqClass(VTable *cvtable)
    : ClassClosure(cvtable) {
        createVanillaPrototype();
    }

    //ScriptObject* ZmqClass::createInstance(VTable* ivtable, ScriptObject* prototype)
    //{
    //    return ZmqObject::create(ivtable->gc(), ivtable, prototype);
    //}


}

extern "C" void zmq_receive_message(char *ptr, void (*receive_message_callback)(char *message)) {
    zmqplus::ZmqSocket * zmq_socket = zmqplus::ZmqSocket::GetInstance();
    zmq::socket_t * socket = zmq_socket->socket;

    std::string message = s_recv(*socket);
    ptr = new char [message.size() + 1];
    strcpy(ptr, message.c_str());

    receive_message_callback(ptr);
}

extern "C" void zmq_reply_message(const char* message) {
    zmqplus::ZmqSocket * zmq_socket = zmqplus::ZmqSocket::GetInstance();
    zmq::socket_t * socket = zmq_socket->socket;
    std::string msg;
    msg.assign(message, strlen(message));
    //std::cout << "reply_message size: " << msg.size() << " " << strlen(message) << std::endl;
    s_send(*socket, message);
}

extern "C" char* zmq_send_message(const char* address, char* message) {
    char* reply = zmqplus::Zmq::sendMessage(address, message);
    return reply;
}

extern "C" int zmq_start_queue(const char *fa, const char *ba, int io_threads, bool singleton_context) {
    zmqplus::Zmq::startQueue(fa, ba, io_threads, singleton_context);
    return 0;
}

extern "C" void * zmq_context() {
    zmqplus::ZmqContext * zmq_context = zmqplus::ZmqContext::GetInstance();
    zmq::context_t * context = zmq_context->context;
    return (void *) context;
}