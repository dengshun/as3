#ifndef __avmplus_ZmqClass__
#define __avmplus_ZmqClass__
#include <zmq.hpp>
#include "shell_toplevel-classes.hh"

namespace zmqplus {

    class ZmqContext {
    public:
        static ZmqContext* GetInstance();
        zmq::context_t * context;
    private:

        ZmqContext();
        ZmqContext(ZmqContext const&);
        ZmqContext& operator=(ZmqContext const&);
        static ZmqContext* pInstance;
    };
    
    class ZmqSocket {
    public:
        static ZmqSocket* GetInstance();
        zmq::socket_t * socket;
    private:

        ZmqSocket();
        ZmqSocket(ZmqSocket const&);
        ZmqSocket& operator=(ZmqSocket const&);
        static ZmqSocket* pInstance;
    };
    
    class Zmq {
    public:
        static char* sendMessage(const char* address, char* message);
        static int startQueue(const char *fa, const char *ba, int io_threads, bool singleton_context);
        zmq::socket_t * socket;
    };
}

namespace avmplus {

    class ZmqObject : public ScriptObject {
    public:
        ZmqObject(VTable* vtable, ScriptObject* delegate);

        bool init(int io_threads, bool singleton_context);
        bool connect(Stringp addressp, int type);
        bool disconnect();
        ByteArrayObject* receive();
        bool send(ByteArrayObject* message);
        zmq::socket_t * socket;
        zmq::context_t * context;

    private:

        DECLARE_SLOTS_ZmqObject;


    };

    class ZmqClass : public ClassClosure {
    public:
        ZmqClass(VTable* vtable);
        //ScriptObject* createInstance(VTable* ivtable, ScriptObject* delegate);

        DECLARE_SLOTS_ZmqClass;
    };


}
#endif 