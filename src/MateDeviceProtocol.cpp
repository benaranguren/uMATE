#include "MateNetPort.h"
#include "MateDeviceProtocol.h"

bool MateDeviceProtocol::recv_packet(OUT uint8_t* port, OUT packet_t* packet)
{
    if (port == nullptr || packet == nullptr)
        return false;

    bool received = recv_data(port, reinterpret_cast<uint8_t*>(packet), sizeof(packet_t));
    if (received) {
        // AVR is little-endian, but protocol is big-endian. Must swap bytes...
        packet->addr = SWAPENDIAN_16(packet->addr);
        packet->param = SWAPENDIAN_16(packet->param);
    }
    return received;
}

void MateDeviceProtocol::send_response(uint8_t port, response_t* response)
{
    if (response == nullptr)
        return;

    response->value = SWAPENDIAN_16(response->value);

    send_data(port, reinterpret_cast<uint8_t*>(response), sizeof(response_t));
}
